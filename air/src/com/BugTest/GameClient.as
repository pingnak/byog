/**

TODO: 
    
    Flesh out mouse inputs for drag/drop.

    Support different resolution layers, e.g. full resolution interface+text layer, on lower resolution game pixels

**/

package com.BugTest
{
    import flash.net.*;
    import flash.system.*;
    import flash.utils.*;
    import flash.events.*;
    import flash.display.*;
    import flash.geom.*;
    
    import com.pingnak.*;

    /**
     * Game client implementation
     *
     * This is what refreshes and generates what a user sees on their client
     * and what handles the inputs from them, as well.  These are generally
     * private for any given user instance, though all could theoretically share 
     * one refresh, from one screen.
    **/
    public class GameClient extends ClientBundle
    {
        [Embed(source="../worker/worker.swf", mimeType="application/octet-stream")] 
        private static const BAWorker:Class;
        internal static function get BABackgroundWorker() : ByteArray { return new BAWorker(); }

        private var target_resolution : uint;
        
        /** Redirection for spammy, floody web clients that open lots of connections */
        private var redirectSock:Socket;

        public var ARENA_SIZE : int = 720;
        public var ARENA_MID : int = 360;
        
        /** Logical position, within main game */
        internal var pan : Rectangle;

        /** What portion of 'pan' client can see */
        internal var clientPan : Rectangle;

        /** Size of sprite buffer being sent to client */
        internal var clientSprite : Rectangle;

        /** Size of client display window */
        internal var clientWidth : int;
        internal var clientHeight : int;

        // Lazy throttle to keep us from flooding our clients
        public var MAX_REFRESH_DEPTH : uint;
        
        /** How many frames we've rendered */
        internal var serverFrame : uint;
        
        /** Our long poll id */
        private var long_poll_id : String;

        /** What frame client says it's on... according to most recent messages */
        internal var clientFrame : uint = 0;

        /** What time client thought it was, when it connected */
        internal var clientConnectionTime : Number = 0;

        /** Time we last heard from client, according to client */
        internal var clientReceptionTime : Number = 0;
        
        protected const DROP_FRAME_THRESHOLD : int = 6; 
        protected const ADD_FRAME_THRESHOLD : int = 2; 
        protected var vScale : Number = 1;
       
        /** Aspect ratio of client wide/high */
        protected var clientAspect : Number = 1;

        /** Scale of client */
        protected var clientScale : Number = 1;

        /** Scale of server side */
        protected var serverScale : Number = 1;
        
        /** Derp validation */
        protected var derpLut : Array;

        /** Derp sequence for ID generation */
        protected var derpSeq : uint;
        
        internal var airplane_speed : Number = 2;
        internal var airplane : MovieClip;
        internal var target_angle : Number;
        
        /** 
         * Timer for inactivity cleanup
         * Browsers open a whole BUNCH of sockets, and then don't use them.
        **/
        private var DoomsDay : Timer;
        private var MS_REASONABLE_INVISIBILITY : uint = 30000;

        /** User interface rendering layer (higher def than sprite) */
        public var ui    : Layer;

        /** Sprite rendering layer */
        public var sprite: Layer;

        /** Tile database/map */
        public var tiles : TileLayer;
       
        /** State machine to control client UI */
        public var fsm : FSM;
        
        public function GameClient( cc : ClientConnection, friendly : String )
        {
            super( cc, friendly );

            // Put some defaults into the various scaling items
            ARENA_SIZE = int(Main.instance.xml.Client_Parameters.ARENA_SIZE);
            ARENA_MID = 0.5 * ARENA_SIZE;
            pan = new Rectangle(0,0, ARENA_SIZE, ARENA_SIZE);
            clientPan = pan.clone();
            clientSprite = pan.clone();
            
            tiles = new TileLayer(pan,1);

            // Get the 
            target_resolution = parseInt(Server.instance.xml.Sprite_Layer.TARGET_RESOLUTION) 

            long_poll_id = String(Server.instance.xml.Client_Parameters.LONG_POLL_XML);
            
            // A pool of work memory
            MAX_REFRESH_DEPTH = 1+Main.instance.stage.frameRate;

            // Add to active game clients
            if( -1 == game_clients.indexOf(this) )
            {
                game_clients.push(this);
            }
            else
            {
                Log( "This was already initialized?" );
            }
            
            // Set up a watchdog timer for closed clients.
            MS_REASONABLE_INVISIBILITY = uint(Main.instance.xml.Client_Parameters.MS_REASONABLE_INVISIBILITY);
            DoomsDay = new Timer(MS_REASONABLE_INVISIBILITY, 1);
            DoomsDay.addEventListener( TimerEvent.TIMER_COMPLETE, DoomsDayHandler );

            // Start timer NOW.  Don't just leave anonymous sockets dangling, forever
            DoomsDayPostpone();
            clientReceptionTime = clientConnectionTime = (new Date()).getTime();
            
            bReady = true;
            derpLut = new Array();
            derpSeq = 0;
            fsm = new FSM(this);
        }

        /**
         * The client sent its first "ready" message.  
        **/
        public function HaveClient() : void
        {
            trace("HaveClient");
            fsm.state = FSM.IDLE;

            // This is just to refresh UI in Main.as... TODO: I need to work on this.
            Main.instance.dispatchEvent( new Event(Server.CONNECTED) );
            
            // Initialize sprite layer
            if( null != sprite )
            {
                InitializedWorker();
                return;
            }
            sprite = new Layer( "sprite", this, Main.instance.mcPlay, Main.instance.mcBugs );
            sprite.addEventListener( Layer.INITIALIZED, InitializedWorker );
            /*
            if( null == bmClient )
            {
                bmClient = new BitmapClient();
                bmClient.InitWorker( InitializedWorker, WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64, 1 );
            }
            */
        }

        /**
         * Callback when worker finished initializing
        **/
        protected function InitializedWorker(e:Event=null):void
        {
            airplane = applet.GetMovieClip("Airplane");
            const airplanes : Array = utils.Shuffle( [1,2,3,4,5,6,7,8,9] );
            var iAirplane : int = airplanes.shift();
            airplanes.push(iAirplane);
            airplane.gotoAndStop( iAirplane );
            airplane.x = (Main.instance.GameWide * 0.25) + int(Main.instance.GameWide * 0.5 * Math.random());
            airplane.y = (Main.instance.GameHigh * 0.25) + int(Main.instance.GameHigh * 0.5 * Math.random());
            target_angle = airplane.rotation = 360 * Math.random();
            utils.RectCenterPt( pan, airplane.x, airplane.y );
            utils.SnapRect(pan);

            // Figure out various parts
            CalcLayers(clientWidth,clientHeight);
            
            // Send a complete background around our position to the client
            Main.instance.tilemap.Update( this, tiles, 10000 );
            
            // Wait for tiles to be processed on client
            SendDerp( "HaveTiles" );
        }
        
        
        public function HaveTiles() : void
        {
            trace("HaveTiles");
            // Show game UI
            fsm.state = "PlayingFirstFrame";
            PlayingFirstFrame();
            //sprite.addEventListener( Layer.REFRESH, SentFirstFrame );
        }
        
        public function PlayingFirstFrame() : void
        {
            if( Render() )
            {   // Once a frame has been rendered, wait for client to get it
                fsm.state = FSM.IDLE;
                SendDerp( "FirstFrameReceived" );
            }
        }

        /**
         * Client received first frame of game.  Turn on display.
        **/
        public function FirstFrameReceived() : void
        {
            WSSendText("uion");
            fsm.state = "Playing";
            Playing();
        }
        
        /**
         * This is where airplane refresh eventually needs to go
        **/
        public function Playing() : Boolean
        {
            Main.instance.mcPlay.addChild(airplane);

            // Turn airplane back towards play field, if it wanders off course
            if( airplane.x + ARENA_MID >= Main.instance.GameWide
             || airplane.x - ARENA_MID <= 0
             || airplane.y + ARENA_MID >= Main.instance.GameHigh
             || airplane.y - ARENA_MID <= 0 )
            {
                target_angle = Math.atan2((0.5*Main.instance.GameHigh)-airplane.y,(0.5*Main.instance.GameWide)-airplane.x) * utils.RAD2DEG;
            }

            var diff : Number = utils.NearestAngle( airplane.rotation*utils.DEG2RAD, target_angle*utils.DEG2RAD ) * utils.RAD2DEG;
            if( Math.abs(diff) < 1 )
            {
                airplane.rotation = target_angle;
            }
            else
            {
                airplane.rotation = airplane.rotation + (diff * 0.5);
            }

            var rad : Number = airplane.rotation * utils.DEG2RAD;
            if( rad > Math.PI )
                rad -= 2*Math.PI;
            airplane.x += Math.cos(rad) * airplane_speed;
            airplane.y += Math.sin(rad) * airplane_speed;
            utils.RectCenterPt( pan, airplane.x, airplane.y );
            utils.SnapRect(pan);
            Main.instance.mcPlay.addChild(airplane);

            // Hold off refreshes, if we are falling behind
            if( MAX_REFRESH_DEPTH < serverFrame - clientFrame )
            {
                //CONFIG::DEBUG { Trace("Backlog",serverFrame,clientFrame); }
                return false;
            }

            if( bWsMode )
            {
                return Render();
            }

            // Long poll mode triggers render separately...
            // TODO: Change how this works...
            return true;
        }
        
        private static var game_clients : Array = new Array();
        public static function get LiveUsers() : int
        {
            return game_clients.length;
        }

        
        /**
         * We've fully received and decoded incoming data in 'Message'.  
         * Do something with it.
        **/
        override public function WSReceivedTextMessage( cc : ClientConnection, str : String ) : Boolean
        {
            DoomsDayPostpone();
            var aParts : Array = str.split(',');
            //CONFIG::DEBUG { if( "frame" != aParts[0] ) trace("WSReceivedTextMessage:",str); }
            var wide : int;
            var high : int;
            switch(aParts.shift())
            {
            case "ready":
                fsm.state = "HaveClient";
            case "frame":   // Just sending frame number to track lag
                clientFrame = int(aParts[0]);
                clientReceptionTime = Number(aParts[1]);
                clientWidth = int(aParts[2]);
                clientHeight= int(aParts[3]);
                if( clientWidth <= 0 || clientHeight <= 0 || clientWidth > 8192 || clientHeight > 8192 )
                {
                    WSSendError( cc, "Bad Size:"+clientWidth+','+clientHeight,1003);
                    return false;
                }
                /*
                var diff : int = sprite.frame - clientFrame;
                if( diff < 0 ) // (diff == 0) would be remarkable...
                {
                    WSSendError( cc, "Time Traveller Detected: "+serverFrame+"/"+clientFrame,1003);
                    return false;
                }
                Needs to be average fps
                if( diff >= DROP_FRAME_THRESHOLD )
                {   // If the client is falling behind, drop some resolution
                    vScale *= 0.90;
                    if( vScale < 0.5 )
                        vScale = 0.5;
                    CalcLayers(clientWidth,clientHeight);
                }
                else if( diff < ADD_FRAME_THRESHOLD )
                {   // If the client is kicking butt, add some more resolution, but more slowly than we subtract
                    vScale *= 1.05;
                    if( vScale > 1 )
                        vScale = 1;
                    CalcLayers(clientWidth,clientHeight);
                }
                */
                CalcLayers( clientWidth, clientHeight );
                ccmain = cc;
                break;

            case "click":
                Click(uint(aParts[0]),parseFloat(aParts[1]),parseFloat(aParts[2]),utils.parseBoolean(aParts[3]),utils.parseBoolean(aParts[4]));
                break;

            case "key":
                aParts.shift();
                clientFrame = uint(aParts.shift());
                Key(clientFrame,aParts);
                // 1..length-1 array members are keypresses
                break;

            /**
             * Handle depth guage repeat message, and verify authenticity
            **/
            case "derp":
                CONFIG::DEBUG { trace(str); }
                var derpKey: String = aParts.shift();
                var derpID : String = derpLut[derpKey] as String;
                if( null != derpID )
                {
                    ReceiveDerp(derpID);
                    delete derpLut[derpKey];
                }
                else
                {
                    WSSendError( cc, "Invalid key:"+derpKey,1003);
                    return false;
                }
                break;
                
            default:
                WSSendError( cc, "No such command.",1003);
                return false;
            }
            return true;
        }

        /**
         * Send depth repeater string
         *
         * This implements a simple callback mechanism to find out when a 
         * previous batch of data sent to the client has actually arrived at, and
         * been processed by the client.  So we need not begin refreshing sprites
         * until an initial set of background tiles have been sent, or begin
         * tracking input events on an interface before it has been displayed.
         *
         * We maintain a database of pending keys, and attach a unique and 
         * unpredictable serial number to each of them.  They need to match, or 
         * the server rejects it.  This should be relatively safe for client 
         * and server.
         *
         * @param id App specific key to additional behavior (secret from client)
        **/
        protected function SendDerp( id : String ) : void
        {
            // 1.[random], 2.[random], 3.[random], ...
            ++derpSeq;
            var key : String = (derpSeq + Math.random()).toFixed(4);
            derpLut[key] = id;
            var msg : String = "derp,"+key;
            WSSendText(msg);
        }

        /**
         * When we get that string back, handle it.
         * @param id App specific key to additional behavior
        **/
        protected function ReceiveDerp( id : String ) : void
        {
            //
            // We expose nothing but a uniquely generated sequential+random 
            // identifier to look up the key.  In this case, state machine state.
            //
            fsm.state = id;
        }

        /**
         * Figure out how to adapt to client screen
        **/
        protected function CalcLayers( wide:int, high:int ) : void
        {
            // Orient our game to the current window shape
            clientAspect = wide/high;
            var altScale : Number = 1;
            if( wide > high )
            {
                if( wide <= ARENA_SIZE )
                {
                    clientScale = 1;
                }
                else
                {
                    clientScale = ARENA_SIZE/wide;
                    // Snap scaling value near 1/int
                    altScale = 1/Math.ceil(wide/ARENA_SIZE);
                    if( Math.abs(clientScale-altScale) < 0.1 )
                        clientScale = altScale;
                }
            }
            else
            {
                if( high <= ARENA_SIZE )
                {
                    clientScale = 1;
                }
                else
                {
                    clientScale = ARENA_SIZE/high;
                    // Snap scaling value near 1/int
                    altScale = 1/Math.ceil(high/ARENA_SIZE);
                    if( Math.abs(clientScale-altScale) < 0.1 )
                        clientScale = altScale;
                }
            }
            utils.RectCenterIn( clientPan, pan );
            utils.SnapRect(clientPan);
            
            clientPan.width = wide * clientScale;
            clientPan.height = high * clientScale;
            clientPan = utils.RectCenterIn(clientPan,pan);
            utils.SnapRect(clientPan);
            tiles.position = clientPan;

            serverScale = vScale * clientScale;

            // Calculate client sprite bitmap size
            clientSprite = pan.clone();
            clientSprite.width = Math.floor( clientSprite.width * serverScale );
            clientSprite.height= Math.floor( clientSprite.height* serverScale );
            
        }
        

        /**
         * Render+Send to client... if ready
        **/
        protected function Render() : Boolean
        {
            // Work out where to render, now
            utils.RectCenterIn( clientPan, pan );
            utils.SnapRect(clientPan);
            clientSprite = clientPan.clone();
            serverScale = vScale * clientScale;
            clientSprite.width = Math.floor( clientSprite.width * serverScale );
            clientSprite.height= Math.floor( clientSprite.height* serverScale );

            // Update tiles behind sprites
            tiles.position = clientPan;
            Main.instance.tilemap.Update( this, tiles, 1 );
            
            // Render next frame of sprite activity
            return sprite.Render( clientPan, serverScale );
        }

        /**
         * Key codes
        **/
        public function Key( frame : uint, aParams : Array ) : Boolean
        {
            CONFIG::DEBUG { Trace("Key:",frame, aParams); }
            
            // We may (or may not) implement keyboard shortcuts for mouse/pad users
            // Key identifiers... another messed up 'standard'.
            // http://www.w3.org/TR/2006/WD-DOM-Level-3-Events-20060413/keyset.html
            // https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent
            // http://unixpapa.com/js/key.html
            return false;
        }

        /**
         * 'Mouse click' 
        **/
        public function Click( frame : int, x:Number, y:Number, shift:Boolean, ctrl:Boolean ) : Boolean
        {
            CONFIG::DEBUG { Trace("Click("+serverFrame+"):",frame,x,y,shift,ctrl); }
            
            // Use the way-back machine map to find out what the user clicked on
            var ptio : Point = new Point(x,y);
            var dobj : DisplayObject = sprite.Click( frame, ptio, shift, ctrl );
            target_angle = utils.Rad2Deg(Math.atan2(ptio.y-airplane.y,ptio.x-airplane.x));
            if( null != dobj )
            {
                Main.instance.ClickOn(dobj,ptio.x,ptio.y);
                return true;
            }
            return false;
        }
        
        public function SendCrunch() : void
        {
            // TODO: Webkit audio to address gnarly tablet sound re-re-re-loading?
            // https://github.com/alexgibson/offlinewebaudio/blob/master/index.html
            // https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#AudioContext-section
            WSSendText( "data,audio/mpeg,crunch.mp3,cache" );
        }

        /**
         * Reset watchdog timer 
        **/
        public function DoomsDayPostpone() : void
        {
            if( null != DoomsDay )
            {
                DoomsDay.reset();
                DoomsDay.start();
            }
        }

        /**
         * Stop watchdog timer 
        **/
        public function DoomsDayCancel() : void
        {
            if( null != DoomsDay )
            {
                DoomsDay.reset();
                DoomsDay.removeEventListener( TimerEvent.TIMER_COMPLETE, DoomsDayHandler );
                DoomsDay = null;
            }
        }

        /**
         * Watchdog to clean up dangling connections
        **/
        protected function DoomsDayHandler(e:Event) : void
        {
CONFIG::DEBUG { Log("DoomsDayHandler!"); }
            DoomsDayCancel();
            Close();
        }
        
        /**
         * We have been closed.
        **/
        override public function Close(e:Event = null ) : void
        {
            Log("GameClient.Close");
            
            fsm.state = FSM.IDLE;

            // Clean up our various render layers
            if( null != tiles )
            {
                Main.instance.tilemap.Purge( this, tiles );
                tiles = null;
            }
            if( null != sprite )
            {
                sprite.Shutdown();
                sprite = null;
            }
            if( null != ui )
            {
                ui.Shutdown();
                ui = null;
            }

            DoomsDayCancel();
            
            // Clean up event listeners
            if( null != airplane && null != airplane.parent )
            {
                airplane.parent.removeChild(airplane);
            }

            var i : int;
            while( -1 != (i=game_clients.indexOf(this)) )
            {
                game_clients.splice(i,1);
            }
            super.Close(e);
            Main.instance.dispatchEvent( new Event(Server.DISCONNECTED) );
        }
        
        /**
         * Receive some kind of http request
         * Should override to receive
         * @param cc ClientConnection which asked for a resource
         * @param address Address separated from header
         * @param header  The rest of the header
         * @param ba      Additional data attached to request
         * @param length  Abount of ba that is message 
         * @return false if unhandled
         * 
         * Inputs potentially come from many sockets, and all end up back here. 
        **/
        override public function HTTPAppMessage( cc : ClientConnection, address : String, header : String, ba : ByteArray, length : uint = 0 ) : Boolean
        {
            function TryFunc() : Boolean
            {
                var aques  : Array = address.split('?');
                if( 2 != aques.length )
                    return false;
                var islash : int = aques[0].lastIndexOf('/');
                if( -1 == islash )
                    return false;
                var resourceID : String = aques[0].slice(islash+1);
                if( long_poll_id != resourceID )
                {
                    return false;
                }
                // Hold off doomsday for a little while longer
                DoomsDayPostpone();
                var params : Array = aques[1].split('&');
                var id : String = params.shift();
                while( 0 != params.length )
                {
                    var param : String = params.shift();
                    WSReceivedTextMessage( cc, param )
                }

                // Send accumulated data to connection that requested this.
                WSEmulatorCommit(cc);

                setTimeout(Render,1);
            }
CONFIG::RELEASE {
            // I want to catch errors, not crash, on release
            try
            {
                return TryFunc();
            }
            catch(e)
            {
                LogError(e);
                cc.HTTPSendBorked("400 Error");
            }
            return false;
}
CONFIG::DEBUG {
            // I want crashes in place, in debug builds
            return TryFunc();
}
        }
        
    }
}
