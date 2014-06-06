package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.geom.*;
    import flash.utils.*;
    
    /**
     * Class to encapsulate a rendering layer
     * 
     * Draws an image to a bitmap, then packs that bitmap and sends it bacl tp
     * associated ClientBundle, when finished
    **/
    public class Layer extends BitmapClient
    {
        /** Initialization event */
        public static const INITIALIZED : String = "initialized";

        /** Destruction event */
        public static const DISPOSED : String = "disposed";

        /** A frame was sent to the client */
        public static const REFRESH : String = "refresh";
        
        /** What to identify layer with */
        protected var id : String;

        /** Who to tell about the wondrous things */
        protected var cb : ClientBundle;

        /** Current image */
        protected var bmCurr : BitmapData;
        
        /** Map of frames we've generated, and sent down to client, with 'old' positions of things */
        protected var clickMap : ClickMap;

        /** Unique server frames (months' worth) */
        protected var frameNumber : uint;
        
        /** Get last rendered frame number */
        public function get frame() : uint { return frameNumber; }
        
        /**
         * @param id ID given to client for image layer
         * @param cb Details about how to talk to client
         * @param mode Optionally override image packaging mode
        **/
        public function Layer( id : String, cb : ClientBundle, mode : uint = WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64 )
        {
            this.id = id;
            this.cb = cb;

            InitWorker( WorkerReady, mode, 1 );
            
            // Map of where things were, when last updata happened, at scale of client
            clickMap = new ClickMap();

            frameNumber = 0;
        }

        /**
         * Worker process is initialized
        **/
        protected function WorkerReady() : void
        {
            dispatchEvent( new Event( INITIALIZED ) );
        }

        /**
         * Render centered on wcX,wcY
         * @param serverFrame A number to identify this frame with, for client/click reference
         * @param dobj What to draw
         * @param dobjInteractive If different from dobj, DisplayObjectContainer to check for clicks in
         * @param wcPan Where to render, within dobj.getBounds(stage), or null == use its own bounding box
         * @param clientScale How to scale the pan window, for the client
         * @return false if render pipeline is backlogged (still busy with previous)
        **/
        public function Render( serverFrame : uint, dobj : DisplayObject, dobjInteractive : DisplayObjectContainer = null, wcPan : Rectangle = null, clientScale : Number = 1 ) : Boolean
        {
            // Get client window position, centered in pan
            if( !ready )
            {
                return false;
            }
            
            frameNumber = serverFrame;
            
            // Make sure pan rect is on pixel bounds
            if( null == wcPan )
            {
                wcPan = dobj.getBounds(dobj.stage);
            }
            utils.SnapRect(wcPan);

            // Convert to client coordinates
            var ccPan : Rectangle = wcPan.clone();
            utils.RectScale(ccPan,clientScale);
            utils.SnapRect(ccPan);
            

            // Start compressing in other thread.
            if( null == bmCurr || ccPan.width != bmCurr.width || ccPan.height != bmCurr.height )
            {
                if( null != bmCurr )
                {
                    bmCurr.dispose();
                }
                bmCurr = new BitmapData(ccPan.width,ccPan.height, true, 0);
            }
            else
            {
                bmCurr.fillRect(bmCurr.rect,0);
            }

            // Draw image to bitmap
            var mux : Matrix = new Matrix( clientScale,0,0,clientScale, -ccPan.x, -ccPan.y );
            bmCurr.draw( dobj, mux );//, null, null, pan, true );
            
            // Record where things were, when this image was made
            clickMap.SnapshotChildren( frameNumber, wcPan, clientScale, null == dobjInteractive ? dobj as DisplayObjectContainer : dobjInteractive );

            // Send bitmap off to be packed
            return RenderToDo( RenderHandler, bmCurr );
        }

        /**
         * When a compress operation has been completed, this sends the message
         * @param bounds What subset of the rectangle was compressed
         * @param message The Base64 encoded data
        **/
        protected function RenderHandler( bounds : Rectangle, message : ByteArray ) : void
        {
            try
            {
                // Send offset to bounding box
                // x offset, y offset, total client width, total client height
                var msg : String = "layr,"+id+","+frameNumber+","+bounds.left+","+bounds.top+","+bmCurr.width+","+bmCurr.height;
                cb.WSSendText(msg);

                // Send the portion that doesn't have stuff scribbled
                if( 0 == bounds.width )
                {   // Send dummy
                    cb.WSSendText(WorkerPackData.b64PNG);
                }
                else
                {
                    cb.WSSendTextFromBA(message,message.position,message.bytesAvailable);
                }

                // Make hooking this easier.
                dispatchEvent( new Event( REFRESH ) );
            }
            catch(e:Error) { debug.TraceError(e); }
            finally
            {
                message = null;
            }
        }

        /**
         * Key codes
        **/
        public function Key( frame : uint, aParams : Array ) : Boolean
        {
CONFIG::DEBUG { debug.Trace("Layer.Key:",frame, aParams); }
            
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
        public function Click( frame : int, ptio : Point, shift:Boolean, ctrl:Boolean ) : DisplayObject
        {
CONFIG::DEBUG { debug.Trace("Layer.Click("+frameNumber+"):",frame,ptio.x,ptio.y,shift,ctrl); }

            // Use the way-back machine map to find out what the user clicked on
            var dobj : DisplayObject = clickMap.ClickedOn( frame, ptio );
CONFIG::DEBUG { debug.Trace(ptio); }
            /*
            if( null != dobj )
            {
                var lp : Point = dobj.globalToLocal(ptio);
                dobj.dispatchEvent( new MouseEvent(MouseEvent.CLICK, true, false, lp.x, lp.y, dobj, ctrl, false, shift, true, 0, false, ctrl) );
            }
            */
            return dobj;
        }
        
        /**
         * Clean up all of this stuff. 
        **/
        override public function Shutdown() : void
        {
            super.Shutdown();
            if( null != bmCurr )
            {
                bmCurr.dispose();
                bmCurr = null;
            }
            dispatchEvent( new Event( DISPOSED ) );
        }
    }
}
