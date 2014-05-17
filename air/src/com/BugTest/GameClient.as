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
        
        /** Map of frames we've generated, and sent down to client, with 'old' positions of things */
        internal var clickMap : ClickMap;
        
        internal var lp_requests : Array;

        protected const DROP_FRAME_THRESHOLD : int = 6; 
        protected const ADD_FRAME_THRESHOLD : int = 2; 
        protected var vScale : Number = 1;
       
        /** Aspect ratio of client wide/high */
        protected var clientAspect : Number = 1;

        /** Scale of client */
        protected var clientScale : Number = 1;

        /** Scale of server side */
        protected var serverScale : Number = 1;
        
        /** Current image */
        protected var bmCurr : BitmapData;
        
        /** Image worker */
        protected var bmClient : BitmapClient;
        
        /** Higher definition UI layer */
        protected var bmUI : BitmapClient;

        /** Current UI */
        protected var uiCurr : Sprite;
        
        /** An empty png image */
        protected var emptyPng : ByteArray;
        
        protected var baPool : ByteArrayPool;
        
        internal var airplane_speed : Number = 2;
        internal var airplane : MovieClip;
        internal var target_angle : Number;
        
        /** 
         * Timer for inactivity cleanup
         * Browsers open a whole BUNCH of sockets, and then don't use them.
        **/
        private var DoomsDay : Timer;
        private var MS_REASONABLE_INVISIBILITY : uint = 30000;
        
        public var tiles : TileLayer;
       
        public var smProgress : FSMDObj;
        
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
            
            clickMap = new ClickMap();
            lp_requests = new Array();

            emptyPng = Main.instance.GetResource("empty.png");

            // A pool of work memory
            baPool = new ByteArrayPool(3,false,false);
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
            
            airplane = applet.GetMovieClip("Airplane");
            const airplanes : Array = utils.Shuffle( [1,2,3,4,5,6,7,8,9] );
            var iAirplane : int = airplanes.shift();
            airplanes.push(iAirplane);
            Main.instance.mcPlay.addChild(airplane);
            airplane.gotoAndStop( iAirplane );
            airplane.x = (Main.instance.GameWide * 0.25) + int(Main.instance.GameWide * 0.5 * Math.random());
            airplane.y = (Main.instance.GameHigh * 0.25) + int(Main.instance.GameHigh * 0.5 * Math.random());
            target_angle = airplane.rotation = 360 * Math.random();
            utils.RectCenterPt( pan, airplane.x, airplane.y );
            utils.SnapRect(pan);
            
            bReady = true;
            
            smProgress = new FSMDObj(this);
            smProgress.state = FSM.IDLE;
            //smProgress.state = "Welcome";
        }

        /**
         * Start up welcome screen
        **/
        public function Welcome() : void
        {
            bmUI = new BitmapClient();
            bmUI.InitWorker( WaitWelcomeReady, WorkerPackData.bPNG | WorkerPackData.bDelta | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64, 1 );
            smProgress.state = FSM.IDLE;
        }
        /**
         * Wait for resources to be available, to render UI layer
        **/
        public function WaitWelcomeReady() : void
        {
            
        }

        public function PickedPlane() : void
        {
        }
        
        public function Playing() : void
        {
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
            case "frame":   // Just sending frame number to track lag
                clientFrame = int(aParts[0]);
                clientReceptionTime = Number(aParts[1]);
                wide = int(aParts[2]);
                high = int(aParts[3]);
                if( wide <= 0 || high <= 0 || wide > 8192 || high > 8192 )
                {
                    WSSendError( cc, "Bad Size:"+wide+','+high,1003);
                    return false;
                }
                var diff : int = serverFrame - clientFrame;
                if( diff < 0 ) // (diff == 0) would be remarkable...
                {
                    WSSendError( cc, "Time Traveller Detected: "+serverFrame+"/"+clientFrame,1003);
                    return false;
                }
                /*
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
                CalcLayers( wide, high );
                ccmain = cc;
                if( null == bmClient )
                {
                    bmClient = new BitmapClient();
                    bmClient.InitWorker( InitializedWorker, WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64, 1 );
                }
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
                
            default:
                WSSendError( cc, "No such command.",1003);
                return false;
            }
            return true;
        }

        /**
         * Figure out how to adapt to client screen
        **/
        protected function CalcLayers( wide:int, high:int ) : void
        {
            clientWidth = wide;
            clientHeight = high;

            // Orient our game to the current window shape
            clientAspect = wide/high;
            var altScale : Number = 1;
            if( wide < high )
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
            
            clientPan.width = wide * clientScale;
            clientPan.height = high * clientScale;
            clientPan = utils.RectCenterIn(clientPan,pan);
            utils.SnapRect(clientPan);

            serverScale = vScale * clientScale;

            // Calculate client sprite bitmap size
            clientSprite = pan.clone();
            clientSprite.width = Math.floor( clientSprite.width * serverScale );
            clientSprite.height= Math.floor( clientSprite.height* serverScale );
            
            removeEventListener( Event.ENTER_FRAME, Heartbeat );
            if( 0 >= clientSprite.width || 0 >= clientSprite.height )
            {
                if( null != bmCurr )
                {
                    bmCurr.dispose();
                    bmCurr = null;
                }
                return;
            }
            addEventListener( Event.ENTER_FRAME, Heartbeat );
        }

        /**
         * Callback when worker finished initializing
        **/
        protected function InitializedWorker():void
        {
            // This is just to refresh UI in Main.as... TODO: I need to work on this.
            Main.instance.dispatchEvent( new Event(Server.CONNECTED) );

        }
        

        /**
         * Render+Send to client... if ready
        **/
        protected function Render() : BitmapData
        {
            utils.RectCenterIn( clientPan, pan );
            utils.SnapRect(clientPan);
            clientSprite = clientPan.clone();
            serverScale = vScale * clientScale;
            clientSprite.width = Math.floor( clientSprite.width * serverScale );
            clientSprite.height= Math.floor( clientSprite.height* serverScale );

            if( null == bmCurr || clientSprite.width != bmCurr.width || clientSprite.height != bmCurr.height )
            {
                if( null != bmCurr )
                {
                    bmCurr.dispose();
                }
                bmCurr = new BitmapData(clientSprite.width,clientSprite.height, true, 0);
            }
            else
            {
                bmCurr.fillRect(bmCurr.rect,0);
            }
            
            // Update tiles behind sprites
            tiles.position = clientPan;
            Main.instance.tilemap.Update( this, tiles, serverFrame < 5 ? 1000 : 1 );

            // Get client window position, centered in pan
            if( null == bmClient || !bmClient.ready )
            {
                return null;
            }
            
            // Generate sprite image
            var mux : Matrix = new Matrix( serverScale,0,0,serverScale, -clientPan.x*serverScale, -clientPan.y*serverScale );
            var mcPlay : MovieClip = Main.instance.mcPlay;
            bmCurr.draw( mcPlay, mux );//, null, null, pan, true );

            if( bmClient.RenderToDo( RenderHandler, bmCurr ) )
            {
                // Record where things were, when this image was made
                var mcBugs : MovieClip = Main.instance.mcBugs;
                clickMap.SnapshotChildren( ++serverFrame, clientPan, serverScale, mcBugs );
            }

            return bmCurr;
        }

        /**
         * Render+Send to client... if ready, and different
        **/
        protected function Heartbeat(e:Event=null) : void
        {
            if( !bReady )
            {
                removeEventListener( Event.ENTER_FRAME, Heartbeat );
                return;
            }
            
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
                return;
            }
            
            if( bWsMode )
            {
                Render();
            }
            // Long poll mode triggers render separately...
        }

        /**
         * Worker thread has data to send back
        **/
        protected function RenderHandler( bounds : Rectangle, message : ByteArray ) : void
        {
            try
            {
                // Send offset to bounding box
                // x offset, y offset, total client width, total client height
                var msg : String = "layr,sprite,"+serverFrame+","+bounds.left+","+bounds.top+","+bmCurr.width+","+bmCurr.height;
                WSSendText(msg);

                // Send the portion that doesn't have stuff scribbled
                if( 0 == bounds.width )
                {   // Send dummy
                    WSSendText(WorkerPackData.b64PNG);
                }
                else
                {
                    WSSendTextFromBA(message,message.position,message.bytesAvailable);
                }
            }
            catch(e:Error) { TraceError(e); }
            finally
            {
                message = null;
            }
        }

        /**
         * Key codes
        **/
        public function Key( frame : uint, aParams : Array ) : void
        {
            Trace("Key:",frame, aParams);
            
            // We may (or may not) implement keyboard shortcuts for mouse/pad users
            // Key identifiers... another messed up 'standard'.
            // http://www.w3.org/TR/2006/WD-DOM-Level-3-Events-20060413/keyset.html
            // https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent
            // http://unixpapa.com/js/key.html
        }

        /**
         * 'Mouse click' 
        **/
        public function Click( frame : int, x:Number, y:Number, shift:Boolean, ctrl:Boolean ) : void
        {
            Trace("Click("+serverFrame+"):",frame,x,y,shift,ctrl);
            
            // Use the way-back machine map to find out what the user clicked on
            var ptio : Point = new Point(x,y);
            var dobj : DisplayObject = clickMap.ClickedOn( frame, ptio );
            if( null != dobj )
            {
                Main.instance.ClickOn(dobj,ptio.x,ptio.y);
            }
            target_angle = utils.Rad2Deg(Math.atan2(ptio.y-airplane.y,ptio.x-airplane.x));
            
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
            removeEventListener( Event.ENTER_FRAME, Heartbeat );
            
            DoomsDayCancel();
            
            // Clean up event listeners
            if( null != airplane.parent )
            {
                airplane.parent.removeChild(airplane);
            }
            
            // Shut down the bitmap pack worker
            if( null != bmClient )
            {
                bmClient.Shutdown();
                bmClient = null;
            }
            if( null != bmUI )
            {
                bmUI.Shutdown();
                bmUI = null;
            }
            

            var i : int;
            while( -1 != (i=game_clients.indexOf(this)) )
            {
                game_clients.splice(i,1);
            }
            if( null != bmCurr )
            {
                bmCurr.dispose();
                bmCurr = null;
            }
            if( null != baPool )
            {
                baPool.Flush();
                baPool = null;
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
            //try
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

                // Send accumulated xml to connection that requested this.
                WSEmulatorCommit(cc);

                setTimeout(Render,1);

            }
            function foo(e):void//catch(e)
            {
                LogError(e);
                cc.HTTPSendBorked("400 Error");
            }
            //finally 
            { 
            }

            return true;
        }
        
    }
}
