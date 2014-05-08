
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    import flash.geom.*;
    import flash.events.*;
    import flash.display.*;
    import flash.text.*;
    import flash.media.*;
    import flash.filters.*;

    import flash.desktop.NativeApplication; 
    import flash.filesystem.*;
    
    /**
     * Utility base class, to make reusing some of the bits and pieces easier
    **/
    public class applet extends MovieClip
    {

        /** App instance */
        public static var instance : applet = null;
        
        public function applet()
        {
            instance = this;

            // Keep kicking the random number generator
            addEventListener( Event.ENTER_FRAME, Entropy );
        }

        /**
         * Keep random output inconsistent
        **/
        internal function Entropy(e:Event=null):void
        {
            Math.random();
        }
        
        /** Get check box state */
        public static function CheckGet(mc:MovieClip):Boolean
        {
            return "on" == mc.currentLabel;
        }
        
        /** Get check box state */
        public static function CheckSet(mc:MovieClip,state:Boolean):void
        {
            mc.gotoAndStop( state ? "on" : "off" );
        }

        /** Get check box state */
        public static function CheckSetup(mc:MovieClip, initialState : Boolean = false):void
        {
            mc.addEventListener( MouseEvent.CLICK, HandleCheck );
            mc.gotoAndStop( initialState ? "on" : "off" );
            function HandleCheck(e:MouseEvent):void
            {
                mc.gotoAndStop("on" == mc.currentLabel ? "off" : "on" ); 
            }
        }

        // A nice disabler helper
        public static function EnableControl(dobj:DisplayObject, bEnable:Boolean = true):void
        {
            if( dobj is InteractiveObject )
            {
                var iobj : InteractiveObject = dobj as InteractiveObject;
                iobj.tabEnabled = iobj.mouseEnabled = bEnable; 
                if( iobj is DisplayObjectContainer )
                    ( iobj as DisplayObjectContainer ).mouseChildren = bEnable;
            }
            dobj.alpha = bEnable ? 1 : 0.5;
        }

        /**
         * Run through a UI and sort its tabs by depth, rather than Flash's random/created order 
         * @param ui Where to start
        **/
        public static function SortTabs(ui:DisplayObjectContainer) : void
        {
            // Make tab order match depth of objects
            var i : int;
            var dobj : InteractiveObject;
            for( i = 0; i < ui.numChildren; ++i )
            {
                dobj = ui.getChildAt(i) as InteractiveObject;
                if( null != dobj )
                {
                    dobj.tabIndex = i;
                }
            }
        }
        
        /**
         * Load a resource that's in a ByteArray
         * @param ba ByteArray to load
         * @return Loader to add events to, or poll, and get the DisplayObject from; or just add it to DisplayList, and let it show up on its own
        **/
        public static function LoadFromByteArray( ba : ByteArray ) : Loader
        {
            var loader : Loader = new Loader();
            var loaderContext:LoaderContext = new LoaderContext(false);
            loaderContext.checkPolicyFile = false;
            loaderContext["allowCodeImport"] = true;
            loaderContext.applicationDomain = ApplicationDomain.currentDomain;
            loader.loadBytes(ba,loaderContext);
            return loader;
        }

        /**
         * Resolve a class id that may have been loaded
         * @param id Class name to resolve
         * @return Class
        **/
        public static function GetClass( id : String ) : Class
        {
            return ApplicationDomain.currentDomain.getDefinition(id) as Class;
        }

        /**
         * Get a DisplayObject from class name
         * @param id Class name to resolve
         * @return MovieClip, or Bitmap, or null
        **/
        public static function GetDisplayObject( id : String ) : DisplayObject
        {
            var cls : Class = ApplicationDomain.currentDomain.getDefinition(id) as Class;
            return new cls() as DisplayObject;
        }

        /**
         * Get a MovieClip from class name
         * @param id Class name to resolve
         * @return MovieClip we're expecting, or null
        **/
        public static function GetMovieClip( id : String ) : MovieClip
        {
            var cls : Class = ApplicationDomain.currentDomain.getDefinition(id) as Class;
            return new cls() as MovieClip;
        }
        
        /**
         * Play a Sound
         * @param id What sound to play (matches class export in Flash)
         * @params... Parameters to pass to Sound.Play
         * @return SoundChannel from play()
        **/
        public static function PlaySound( id : String, ...params ) : SoundChannel
        {
            var cls : Class = ApplicationDomain.currentDomain.getDefinition(id) as Class;
            var sound : Sound = new cls();
            return sound.play.apply(id,params);
        }

        
        /**
         * Load a text file (e.g. HTML template parts)
         * @param path Where to find the text
         * @return String containing the text
        **/
        public static function LoadText( path:String ) : String
        {
            try
            {
                var root : File = File.applicationDirectory;
                var f : File = new File( root.url + path );
                if( f.exists && !f.isDirectory )
                {
                    var fs:FileStream = new FileStream();
                    fs.open(f, FileMode.READ);
                    var ret : String = fs.readUTFBytes(fs.bytesAvailable);
                    fs.close();
                    return ret;
                }
                else
                {
                    debug.LogError(path,"Not Found");
                }
            }
            catch(e:Error)
            {
                debug.LogError(path, e.toString());
            }
            return "";
        }

        /**
         * Load a data file
         * @param path Where to find the text
         * @return String containing the text
        **/
        public static function LoadData( path:String ) : ByteArray
        {
            try
            {
                var root : File = File.applicationDirectory;
                var f : File = new File( root.url + path );
                if( f.exists && !f.isDirectory )
                {
                    var fs:FileStream = new FileStream();
                    fs.open(f, FileMode.READ);
                    var ret : ByteArray = new ByteArray();
                    fs.readBytes(ret,0,fs.bytesAvailable);
                    fs.close();
                    return ret;
                }
                else
                {
                    debug.LogError(path,"Not Found");
                }
            }
            catch(e:Error)
            {
                debug.LogError(path, e.toString());
            }
            return null;
        }

        
    }
}
    
