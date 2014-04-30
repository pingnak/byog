
package com.BugTest
{
    import flash.net.*;
    import flash.system.*;
    import flash.utils.*;
    import flash.geom.*;
    import flash.events.*;
    import flash.display.*;
    import flash.text.*;
    import flash.media.*;
    import flash.filters.*;

    import flash.desktop.NativeApplication; 
    import flash.desktop.SystemIdleMode;
    import flash.filesystem.*;

    import com.pingnak.*;
    
    /**
     * This server isn't meant to play for a cast of thousands. 
     *
     *
     * When this is converted to a 'Worker', maintain semaphores for output progress
     * and readiness for another frame.
     *
     * We'll probably need to rewrite the Worker/Primordial threads to pass 
     * ByteArray from images, and do the 'swap' with 32 bit values.
     *
     * In deference to truly rotten tablet/phone clients that should all have 
     * native PNG support in their browsers, we will farm some extra work to the 
     * 'more powerful' PC/notebook to be friendlier to that path, and pre-encode 
     * it to base64 on the server side, as part of that mess.
     *
     * This, instead of sending it down in binary format, then having to make it into 
     * base64 format on the client, only to make it binary again, which on a weak
     * tablet or phone, is extra load on limited CPU and battery resources.
     *
     * All because 'Image' doesn't take a binary PNG file image.
     * It takes base64... ONLY.
     *
     * On the plus side, we can send everything with text-only messages, making 
     * the protocol clear and obvious to anyone who wants to check for evil.  
     *
     * On the minus side, added server overhead and 4/3 bloat on encoded output.
     *
     * Everything is subject to endless tinkering.
     *
     * Naturally, WebSocket communications are ridiculously complex, as per the web standards standard.
     * See also: Draft RFC6455
     * https://github.com/Worlize/AS3WebSocket
     * https://as3corelib.googlecode.com/svn/trunk/src/com/adobe/crypto/SHA1.as
     *
     * We will send base64 data as the data, because to parse with javascript 
     * string.split would make an extra copy of the whole thing, and iterating  
     * characters in script code is slow.
     *
     * Yes, it's all based on 'four letter words'.
     *     
     * Server to client:
     * orig,x,y Png origin for next data:image message (resets to 0,0 afterwards)
     * data:image/png;base64 A PNG image to paste at origin
     * data:image/jpeg;base64 A losslessly compressed JPEG image to paste at origin
     * data:audio/ogg;base64 An ogg sample to play, right now
     * data:audio/mp3;base64 An mp3 sample to play, right now
     *
     * Client to server:
     * down,x,y: Mouse/finger down 
     * move,x,y: Mouse/finger track
     * drop,x,y: Mouse/finger raised/released
     * keys,keypresses: All keyboard inputs into page (user may be quick typist) 
     *
     * Future support: speech recognition/assistive speech (whenever a standard firms up for it)
     * says,XML/strings 'Hot spots' for assistive devices (read subs for people whose eyes are good enough to play, but not read)
     * said,string Alternate speech based text input
     *
    **/
    public class Main extends Server
    {
        public static function get instance() : Main { return Server.instance as Main; }

        internal static const SO_PATH : String = "ServerPreferences";
        internal static const SO_SIGN : String = "SERVER_PREF_SIGN_00";
        
        internal var GameWide : Number;
        internal var GameHigh : Number;

        // Current UI
        public var ui : MovieClip;
        public var mcMask : MovieClip;
        public var mcPlay : MovieClip;
        public var  mcBugs : MovieClip;
        
        public var tilemap : TileCache;
        
        private var bugPool : Pool;
        private var bamfPool : Pool;

        private var bugs : Array;
        private var SpawnRate : uint = 500;     // How long between bug spawns
        private var LastSpawn : uint = 0;
        private var TravelTime : uint = 60000;   // How long for bug to run across screen 

        private var targetX : Number;
        private var targetY : Number;
        private var spawnTimer : Timer;

        internal var nFrames : int;
        internal var aFrames : Array;

        /*
         * We need to maintain a current, previous images
         * Current is what we render now
         * Previous is the last image we sent
         * Diff is a bitmap with the 'same' pixels on curr/prev zeroed out
         */
        /** Encode as PNG; be quicker about it */
        internal static const EncoderOptions : Object = new PNGEncoderOptions(true);
        internal var bmCurr : BitmapData;
        internal var bmPrev : BitmapData;

        public function Main()
        {
            var txt : String = applet.LoadText("server/server.xml");
            super(new XML(txt),ClientConnection);
            CONFIG::DEBUG
            {
                debug.Log( "DEBUG BUILD" );
            }
            debug.Log( debug.LOG_IMPORTANT, loaderInfo.url,CONFIG::TIME );
            debug.Log( debug.LOG_IMPORTANT, Capabilities.os,Capabilities.playerType,Capabilities.version );
            debug.Log( debug.LOG_IMPORTANT, Capabilities.serverString );
            trace("---------------------\n");
            
            tilemap = new TileCache("Ground", int(xml.Client_Parameters.TILE_WIDE), int(xml.Client_Parameters.TILE_HIGH) );

            var root : File = File.applicationDirectory;
            var file : File = new File( root.url + String(xml.tilemap) );
            tilemap.FromRendered( file );
            
            // Built by Flash, so resources are already loaded+initialized
            UI_Ready();

            /** Set game client in charge of client bundles */
            ClientBundle.ClientClass = GameClient;

            NativeApplication.nativeApplication.addEventListener( Event.EXITING, Close );
        }

        /**
         * UI is decoded and ready for use
        **/
        public function UI_Ready(e:Event=null) : void
        {
            ui = GetMovieClip("MainUI");
            SortTabs(ui);
            addChild(ui);
            
            stage.quality = StageQuality.LOW;
            
            mcMask = ui.mcGameUI.mcMask;
            mcPlay = ui.mcGameUI.mcPlay;
            mcBugs = mcPlay.mcBugs;

            GameWide = mcMask.width;
            GameHigh = mcMask.height;
            
            applet.CheckSetup( ui.mcbScrollLock, false );
            
            applet.CheckSetup( ui.mcbRUN, false );
            ui.mcbRUN.addEventListener( MouseEvent.CLICK, GoButton );

            ui.tfPort.restrict = "0-9";
            ui.tfPort.maxChars = 5;
            ui.tfPort.addEventListener( KeyboardEvent.KEY_DOWN, HitEnter );
            
            ui.tfUsers.text = "0";
            addEventListener( Server.CONNECTED, updateUsers );
            addEventListener( Server.DISCONNECTED, updateUsers ); 

            LoadSharedData();

            // Suck in any logs that happened while waiting for UI to initialize
            var aLog : Array = debug.GetLog();
            while( 0 < aLog.length )
            {
                AddToLog( aLog.shift() );
            }
            // Listen for new log events to display (and whatever else)
            debug.addEventListener( debug.DEBUG_LOG, Logged );

            UpdateIPList();
            
        }

        private function updateUsers(e:Event=null):void
        {
            ui.tfUsers.text = GameClient.LiveUsers;
        }
        
        /**
         * Generate list of connectable IP addresses
        **/
        private function UpdateIPList(e:Event=null):void
        {
            var aip : Array = Server.GetInterfaces();
            var tf : String = "";
            var curr : String;
            var port : int = uint(ui.tfPort.text);
            while( 0 < aip.length )
            {
                curr = aip.shift();
                tf += "http://"+curr+":"+port+(0<aip.length?", ":"");
            }
            ui.tfIP.text = tf;
        }

        // Convenience - hit enter in port to start up
        private function HitEnter(event:KeyboardEvent):void
        {
            UpdateIPList();
            // if the key is ENTER
            if(13 == event.charCode)
            {
               // your code here
                GoButton();
            }
        }

        /**
         * Refresh application log event handler
        **/
        private function Logged(e:TextEvent):void
        {
            AddToLog( e.text );
        }

        /**
         * Tack something into application log, keep the window scrolled
        **/
        internal function AddToLog(sz:String):void
        {
            var tf : TextField = ui.tfLog;
            tf.appendText( sz );
            if( !applet.CheckGet(ui.mcbScrollLock) )
            {
                tf.scrollV = tf.maxScrollV;
            }
            if( tf.numLines > debug.LOG_MAX )
            {
                var curLine : int = tf.scrollV-1;
                tf.text = tf.text.substring(tf.getLineLength(0));
                tf.scrollV = curLine;
            }
        }

        /**
         * Reset persistent settings
        **/
        protected function ResetSharedData() : Object
        {
            ui.tfPort.text = String(xml.port);
            return CommitSharedData();
        }
        
        /**
         * Load and apply persistent settings
        **/
        protected function LoadSharedData():void
        {
            trace("LoadSharedData");
            
            var share_data : Object; 

            try
            {
                var f:File = File.applicationStorageDirectory.resolvePath(SO_PATH);
                if( !f.exists )
                {
                    trace("NO SETTINGS");
                    ResetSharedData();
                    return;
                }
 
                // Grab the data object out of the file
                var fs:FileStream = new FileStream();
                fs.open(f, FileMode.READ);
                share_data = fs.readObject();
                fs.close();
            }
            catch( e:Error )
            {
                trace(e,e.getStackTrace());
                share_data.sign = 0;
            }

            // Verify version compatibility
            if( SO_SIGN != share_data.sign )
            {
                share_data = ResetSharedData();
            }
            
            // Decode the saved data
            var default_port : String = share_data.default_port as String;
            if( null == default_port || "" == default_port )
                share_data = ResetSharedData();
            ui.tfPort.text = share_data.default_port;
        }
        
        /**
         * Save persistent settings
        **/
        public function CommitSharedData() : Object
        {
            var share_data : Object = {}; 

            // Get file 
            var f:File = File.applicationStorageDirectory.resolvePath(SO_PATH);
            var fs:FileStream = new FileStream();
            fs.open(f, FileMode.WRITE);

            // Copy data to our save 'object
            share_data.default_port = ui.tfPort.text;

            share_data.sign = SO_SIGN;

            // Commit file stream
            fs.writeObject(share_data);
            fs.close();
            
            // Return our object for reference
            return share_data;
        }
        
        /**
         * Start the server
        **/
        private function GoButton(e:Event=null):void
        {
            // Now would be a very good time to clean up the heap            
            System.pauseForGCIfCollectionImminent(0.01);
            if( !Running() )
            {
                var port : int = uint(ui.tfPort.text);
                if( port < 1024 )
                {
                    debug.Log(debug.LOG_ERROR,"Port number must >= 1024." );
                    ui.tfPort.text = "9999";
                }
                else
                {
                    debug.Log( debug.LOG_IMPORTANT, "Go!", String(xml.ip), port );
                    CommitSharedData();
                    if( Connect( String(xml.ip), port ) )
                    {
                        applet.CheckSet(ui.mcbRUN,InitGame());
                        UpdateIPList();
                        ui.tfPort.selectable = false;
                        ui.tfPort.type = TextFieldType.DYNAMIC;
                        // Give computer insomnia while running server
                        NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.KEEP_AWAKE;
                        return;
                    }
                }
            }
            debug.Log( debug.LOG_IMPORTANT, "Server Stop!" );
            StopGame();
            Close();
            applet.CheckSet(ui.mcbRUN,false);
            ui.tfPort.selectable = true;
            ui.tfPort.type = TextFieldType.INPUT;
            NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.NORMAL;
        }

        
        /**
         * Start the game
        **/
        private function InitGame() : Boolean
        {
            var nBugs : int = 2*int(TravelTime/SpawnRate);
            if( null == bugPool )
                bugPool = new MCPool(GetClass( "Bug" ),nBugs,false);
            if( null == bamfPool )
                bamfPool = new MCPool(GetClass( "Bang" ),nBugs,false);
            
            targetX = 0.5 * GameWide; 
            targetY = 0.5 * GameHigh;
            bugs = new Array();
            spawnTimer = new Timer(SpawnRate);
            spawnTimer.start();
            spawnTimer.addEventListener(TimerEvent.TIMER, SpawnBug);
            mcPlay.addEventListener( Event.ENTER_FRAME, Refresh );
            mcPlay.addEventListener( MouseEvent.MOUSE_DOWN, ClickMe );
            nFrames = 0;
            aFrames = new Array();
            return true;
        }

        /**
         * Stop the game
        **/
        private function StopGame() : void
        {
            if( null != spawnTimer )
            {   // Stop spawning
                spawnTimer.stop();
                spawnTimer = null;
            }
            if( null != bugs )
            {   // Kill all bugs
                var bug : MovieClip;
                while( 0 != bugs.length )
                {
                    bug = bugs.shift();
                    bugDeath(bug);
                }
            }
            mcPlay.removeEventListener( Event.ENTER_FRAME, Refresh );
            mcPlay.removeEventListener( MouseEvent.MOUSE_DOWN, ClickMe );
            
            nFrames = 0;
            aFrames = new Array();
            
        }

        public function Refresh(e:Event):void
        {
            ++nFrames;
            //aFrames
        }
        
        /**
         * Key codes
        **/
        override public function Key( str : String ) : void
        {
        }

        /**
         * local click
        **/
        private function ClickMe(e:MouseEvent):void
        {
            	Click( mcPlay.mouseX, mcPlay.mouseY ); 
        }
        
        /**
         * 'Mouse click' 
        **/
        override public function Click( x:Number, y:Number ) : void
        {
            var i : int;
            var bug : MovieClip;
            var pt : Point = mcPlay.localToGlobal(new Point(x,y));
            for( i = 0; i < bugs.length; ++i )
            {
                bug = bugs[i];
                if( bug.hitTestPoint( pt.x,pt.y, false) )
                {
                    ClickOn(bug,x,y);
                }
            }
        }

        override public function ClickOn( dobj : DisplayObject, mx:Number, my:Number ) : void
        {
            trace( "ClickOn", mx, my );
            var bug : MovieClip = dobj as MovieClip;
            if( null != bug )
            {
                if( bugDeath(bug) )
                {
                    var bamf : MovieClip = bamfPool.New();
                    mcPlay.addChild(bamf);
                    bamf.addEventListener( MCE.LAST, StopIt );
                    MCE.Enable(bamf);
                    bamf.play();
                    bamf.x = mx; 
                    bamf.y = my; 
                    bamf.rotation = 360 * Math.random();
                    bamf.mouseEnabled = bamf.mouseChildren = false;
                    function StopIt(e:MCE) : void
                    {
                        var mc : MovieClip = e.target as MovieClip;
                        mc.removeEventListener( MCE.LAST, StopIt );
                        mc.stop();
                        bamfPool.Delete(mc);
                    }
                    ClientBundle.ForEachBundle( crunch );
                    function crunch(cb:ClientBundle):void
                    {
                        var gc : GameClient = cb as GameClient;
                        if( null != gc )
                        {
                            gc.SendCrunch();
                        }
                    }
                }
            }
        }

        /**
         * Make a new bug
        **/
        private function SpawnBug(e:Event) : void
        {
            //trace("SpawnBug");

            var bug : MovieClip = bugPool.New();
            if( null == bug )
                return;
            
            bugs.push(bug);
            mcBugs.addChild(bug);
            
            // Pick a point around the center of the screen as bug target
            var midX : Number = targetX - (0.25*targetX) + (Math.random() * targetX);
            var midY : Number = targetY - (0.25*targetY) + (Math.random() * targetY);
            
            // Pick a direction, and scoot bug from off-screen to off-screen, through its point
            var radian : Number = 2 * Math.PI * Math.random();
            bug.rotation = 180 * radian / Math.PI;
            bug.scaleX = bug.scaleY = 0.11 + (0.22 * Math.random());
            
            // Set begin and end points
            var startX : Number = midX - (Math.cos(radian) * (1.42*GameWide)); // sqrt(2) rounded up
            var startY : Number = midY - (Math.sin(radian) * (1.42*GameWide));
            var endX  : Number =  midX + (Math.cos(radian) * (1.42*GameWide));
            var endY  : Number =  midY + (Math.sin(radian) * (1.42*GameWide));
            
            bug.x = startX;
            bug.y = startY;
            bug.addEventListener( MCM.STOPPED, bugDeathEvent );
            MCM.GoTo( bug, endX, endY, TravelTime );
            bug.play();
        }

        private function bugDeathEvent(e:Event):void
        {
            var bug : MovieClip = e.target as MovieClip;
            bugDeath(bug);
        }

        // Kill a bug
        private function bugDeath(bug:MovieClip):Boolean
        {
            // remove from bug list
            bug.stop();
            bug.removeEventListener( Event.REMOVED_FROM_STAGE, bugDeathEvent );
            bug.removeEventListener( MCM.STOPPED, bugDeathEvent );
            if( mcBugs == bug.parent )
            {
                mcBugs.removeChild(bug);
            }
            var i : int = bugs.indexOf(bug);
            if( -1 != i )
            {
                bugs.splice(i,1);
                bugPool.Delete(bug);
                return true;
            }
            return false;
        }
    }
}
