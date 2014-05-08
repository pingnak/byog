
package com.swf2psd
{
    import flash.desktop.*;
    	import flash.filesystem.*;
    import flash.system.*;
    import flash.utils.*;
    	import flash.display.*;
    	import flash.geom.*;
    import flash.events.*;
    import flash.net.URLRequest;
    
    import com.pingnak.*;

    /**
     * This is a bit of a detour, so I'm not going to spend much time without
     * any external demand for it.  
     *
     * Basically, animated things are 'modeled', and this attempts to break down
     * exported symbols within an existing swf into a 2D, layered model, and
     * maintain the relative positions and origins of its components, already 
     * painstakingly set within Flash or Photoshop.
     *
     * Somehow, the folks at Unity don't appear to understand the importance for
     * artists to lay things out visually, in tools familiar to them, and appear 
     * to believe there is zero labor involved with repetitively picking imagery   
     * apart by hand, to spoon feed it to a much-too-simple import, that ends
     * up making a puzzle, only to be re-assembled in their GUI with even more
     * labor, usually by someone else, because the ones who are really good at
     * making the prettiest art are usually borderline computer illiterate.
     *
     * I will define an XML script to control the tasks, rather than a GUI, as
     * this is more the 'build it' end of things than the 'draw it', and 
     * relationships between shared content and imported symbols don't make it 
     * through when someone who 'needs a GUI' uses one.  Also, this would be
     * miserably repetitive and error-prone to poke check marks and navigate
     * paths, rather than simply give it a to-do list, and let it do its 
     * business.
     * 
     * This tool will do a few well defined tasks:
     *
     * SWF To PSD
     *
     * Run through a MovieClip, recursively, find every unique reference to 
     * 'something', and render those 'Somethings' into a layered PSD file, 
     * with all of the parts in their correct relative positions, if not their
     * correct orientations (you may have to mirror/rotate/flip things in the 
     * unity animator, because there aren't enough parameters to pass to the 
     * SpriteMetaData object, to control how things are eventually laid out.
     *
     * The PSD file will have a control layer, named 'origin'.  A quick scan from
     * top->bottom, left->right for non-transparent finds a pixel, that position 
     * becomes the origin.  If you define multiple origin layers, only the first
     * one discovered will be used.  Something like an arrow pointing up/left 
     * would work as the origin specifier, but it's just looking for that set 
     * pixel.
     * 
     * SWF To Atlas
     *
     * Do the same as above, but spit all of the layers out into a big, fat
     * png file, with some contextual krazy glue for a Unity AssetPostprocessor
     * script to pick over.  Since Unity does its own sprite packing, I don't 
     * need to concentrate on packing them together, here.  Only getting them
     * into unity, and identifying WHERE THEY BELONG and/or where the grab point 
     * is.
     *
     * PSD To Atlas
     *
     * Take a layered PSD, similar to what this makes, and spit out the same 
     * Atlas data and image.  Because designing a whole UI or level as a layered 
     * PSD is pretty easy, and saves a lot of time and miserable drudgery. 
    **/
    public class Swf2Psd extends applet
    {
        internal var mcMain : MovieClip;

        /** Image we are exporting into */
        internal var bmOutput : BitmapData;

        internal var bmFrame : BitmapData;

        // Bounding box for current export 
        internal var bounds : Rectangle;
        
        // List of named symbols that MovieClip was composed of; keep only unique
        internal var Database : Dictionary;

        // List of objects that MovieClip was composed of
        internal var mcCurr : DisplayObject;
        
        public function Swf2Psd()
        {
            // Accept shell actions to 'invoke' this, like launch parameters and 
            mcMain = new UI_Settings();
            mcMain.stop();
            addChild( mcMain );

            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, onInvokeEvent); 
        }

        /**
         * Grab parameters when we launch, or when one of our '.swf2psd' files
         * is double-clicked/launched.
        **/
        internal function onInvokeEvent(invocation:InvokeEvent):void 
        { 
            var arguments : Array = invocation.arguments;
            debug.Log("onInvokeEvent:",arguments);
            while( 0 < arguments.length )
            {
                var f : File = new File();
                f.nativePath = arguments.shift();
                var szXML : String = null;
                if( f.exists && !f.isDirectory )
                {
                    var fs:FileStream = new FileStream();
                    fs.open(f, FileMode.READ);
                    szXML = fs.readUTFBytes(fs.bytesAvailable);
                    fs.close();
                }
                if( null != szXML )
                {
                    try
                    {
                        Process( new XML(szXML) );
                    }
                    catch(e:Error)
                    {   // We need to catch invalid XML
                        debug.LogError("Error processing:",szXML);
                        debug.LogError(e.toString());
                    }
                }
            }
        } 

        /**
         * Parse the XML, do the dirty deeds it specifies
         * @param xml XML data, ready to process.
        **/
        internal function Process(xml:XML):void
        {
            trace("Process");
            var xmlList : XMLList = xml.export;
            var i : int;
            var xmlCurr : XML;
            var szOutput : String;
            var iExt : int;
            var szExt: String;
            for( i = 0; i < xmlList.length(); ++i )
            {
                xmlCurr = XML(xmlList[i]);
                szOutput = String(xmlCurr.@path);
                iExt = szOutput.lastIndexOf('.');
                szExt= szOutput.slice(iExt).toLowerCase();
                trace(iExt,szExt);
                /*
                if( ".psd" == szExt )
                {
                    try
                    {
                        ExportPSD(xmlCurr);
                    }
                    catch(e:Error)
                    {
                        debug.LogError("Error while generating", szOutput);
                        debug.LogError(e.toString());
                    }
                }
                else*/ if( ".png" == szExt )
                {
                    try
                    {
                        ExportPNG(xmlCurr);
                    }
                    catch(e:Error)
                    {
                        debug.LogError("Error while generating", szOutput);
                        debug.LogError(e.toString());
                    }
                }
                else
                {
                    debug.LogError("Unsupported export:", szOutput);
                }
            }

        }

        /**
         * We're going to slurp up imports and dump them into named PSD layers.
        internal function ExportPSD(xml:XML):void
        {
            // We'll do the PSD first, since it's simpler.
        }
        **/
        /**
         * Import PSD layers, according to XML 
        internal function ImportPSD( xml:XML ) : void
        {
        }
        **/
        
        /**
         * We're going to slurp up imports and dump them into a png, and generate 
         * a text file to go along with it, describing where the parts are.
        **/
        internal function ExportPNG(xml:XML):void
        {
            trace("ExportPNG");
            var szOutput : String = String(xml.@path);
            var i : int;
            var xmlCurr : XML;
            var xmlList : XMLList = xml.children();
            for( i = 0; i < xmlList.length(); ++i )
            {
                xmlCurr = XML(xmlList[i]);
                if( 'swf' == xmlCurr.name() )
                    ImportSWF(xmlCurr);
            }            
        }
        
        /**
         * Start in on a swf import, add parts to layers
        **/
        internal function ImportSWF( xml:XML ) : void
        {
            var szInput : String = String(xml.@path);
            var loader : Loader = new Loader();
            var loaderContext:LoaderContext = new LoaderContext(false);
            loaderContext.checkPolicyFile = false;
            loaderContext["allowCodeImport"] = true;
            loaderContext.applicationDomain = ApplicationDomain.currentDomain;
            debug.TraceDownload(loader);
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,Loaded);
            	loader.load( new URLRequest(szInput), loaderContext );
            	function Loaded(e:Event):void
            	{
            	    trace("Loaded");
                bounds = new Rectangle();

                // Figure out a bounding box for all of these
                var i : int;
                var xmlCurr : XML;
                var xmlList : XMLList = xml.children();
                var cls : Class;
                var dobj : DisplayObject;
                for( i = 0; i < xmlList.length(); ++i )
                {
                    xmlCurr = XML(xmlList[i]);
                    cls = GetClass( String(xmlCurr.@id) );
                    dobj = new cls();
                    bounds = bounds.union(MeasureAllFrames(dobj));
                }
                trace("All clips:",bounds);
                
                // Now build a list of correctly oriented things, aligned within the bounding box
                for( i = 0; i < xmlList.length(); ++i )
                {
                    xmlCurr = XML(xmlList[i]);
                    ImportSWFSymbol(xmlCurr);
                }
            	    loader.unloadAndStop(true);
            	}
        }

        /**
         * Pick apart a symbol within ImportSWF, add parts to layers 
        **/
        internal function ImportSWFSymbol( xml:XML ) : void
        {
            trace("ImportSWFSymbol",xml.toXMLString());
            var cls : Class = GetClass( String(xml.@id) );
            var mc : MovieClip = new cls();
            trace(bounds);
        }
        
        
        /**
         * What we actually have to do is PLAY each MovieClip, from start to end.
         * 
         * From back, to front, find DisplayObjects and convert discovered 
         * MovieClips and their NON-MovieClip children into Bitmaps, and then
         * hide them, so the higher level 
        **/
        internal function RecurseInto( dobj : DisplayObject ) : int
        {
            var totalFound : int = 0;
            var childrenFound : int;
            if( null == dobj )
                return totalFound;
            if( dobj is DisplayObjectContainer )
            {
                var dobjc : DisplayObjectContainer = dobj as DisplayObjectContainer;
                var total : int = dobjc.numChildren;
                var dobjCurr : DisplayObject;
                var curr : int;
                for( curr = 0; curr < total; ++curr )
                {
                    dobjCurr = dobjc.getChildAt(curr);
                    childrenFound = RecurseInto(dobjCurr);
                    //...
                    totalFound += childrenFound;
                }
            }
            // Render this into frame; if empty frame, don't save it.

            //bmFrame.draw(dobj);
            
            // Make it invisible, so higher order renders don't replicate it.
            dobjc.visible = false;
            return totalFound;
        }

        /**
         * Setting position to {0,0}, measure every frame, and make a bounding box
         * 
        **/
        internal function MeasureAllFrames( dobj : DisplayObject, scale : Number = 1 ) : Rectangle
        {
            var rBounds : Rectangle;
            var tx : Number = dobj.x;
            var ty : Number = dobj.y;
            var tp : DisplayObjectContainer = dobj.parent;
            
            stage.addChild(dobj);
            dobj.x = dobj.y = 0;
            dobj.rotation = 0;
            dobj.scaleX = dobj.scaleY = scale;
            if( dobj is MovieClip )
            {
                var mc : MovieClip = dobj as MovieClip;
                mc.gotoAndStop(1);
                rBounds = mc.getBounds(stage);
                while( mc.currentFrame < mc.totalFrames )
                {
                    mc.nextFrame();
                    rBounds = rBounds.union(mc.getBounds(stage));                    
                }
            }
            else
            {
                rBounds = dobj.getBounds(stage);
            }
            if( null != tp )
                tp.addChild(dobj);
            else
                stage.removeChild(dobj);
            dobj.x = tx;
            dobj.y = ty;
            
            // I only want to deal with whole pixels
            rBounds.left = Math.floor(rBounds.left);
            rBounds.top = Math.floor(rBounds.top);
            rBounds.width = Math.ceil(rBounds.width);
            rBounds.height = Math.ceil(rBounds.height);
            return rBounds;
        }
        
    }
}
