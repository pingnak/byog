package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Class to encapsulate a rendering layer
     * 
     * Draws an image to a bitmap, then packs that bitmap and sends it onwards
    **/
    public class Layer extends BitmapClient
    {
        /** Initialization event */
        public static const INITIALIZED : String = "initialized";

        /** Destruction event */
        public static const DISPOSED : String = "disposed";
        
        /** What to identify layer with */
        protected var id : String;

        /** Who to tell about the wondrous things */
        protected var cb : ClientBundlel;

        /** Current image */
        protected var bmCurr : BitmapData;
        
        /** What to draw into the bitmap */
        protected var dobj : DisplayObject;
        protected var dobjInteractive : DisplayObject;
        
        /** Map of frames we've generated, and sent down to client, with 'old' positions of things */
        protected var clickMap : ClickMap;

        /** Unique server frames (months' worth) */
        protected var frameNumber : uint;
        
        /** Scaling applied from world coords to client */
        protected var clientScale : Number = 1;
        
        /** Set scaling from world coordinate to client resolution */
        public function set scale(scale:Number):void { clientScale = scale; }
        public function get scale():void { return clientScale; }
        
        /**
         * @param id ID given to client for image layer
         * @param cb Details about how to talk to client
         * @param dobj What to draw
         * @param dobjInteractive If different from dobj, DisplayObject to check for clicks in  
        **/
        public function Layer( id : String, cb : ClientBundle, dobj : DisplayObject, dobjInteractive : DisplayObject = null )
        {
            this.id = id;
            this.cb = cb;
            this.dobj = dobj;
            this.dobjInteractive = null == dobjInteractive ? dobj : dobjInteractive;
            InitWorker( InitializedWorker, WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64, 1 );
            
            // Map of where things were, when last updata happened, at scale of client
            clickMap = new ClickMap();

            frameNumber = 0;
        }

        /**
         * Render centered on wcX,wcY
         * @param wcPan Where to render, within dobj.getBounds(stage), or null == use its own bounding box
         * @return false if render pipeline is backlogged (still busy with previous)
        **/
        public function Render( wcPan : Rectangle = null ) : Boolean
        {
            // Get client window position, centered in pan
            if( !ready )
            {
                return false;
            }
            
            ++frameNumber;
            
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
            
            // Generate sprite image
            var mux : Matrix = new Matrix( clientScale,0,0,clientScale, -ccPan.x, -ccPan.y );
            var mcPlay : MovieClip = Main.instance.mcPlay;
            bmCurr.draw( mcPlay, mux );//, null, null, pan, true );

            // Start compressing in other thread.
            if( bmClient.RenderToDo( RenderHandler, bmCurr ) )
            {
                // Record where things were, when this image was made
                var mcBugs : MovieClip = Main.instance.mcBugs;
                clickMap.SnapshotChildren( frameNumber, ccPan, clientScale, dobjInteractive );
                return true;
            }
            return false;
        }
        
        protected function InitializedWorker() : void
        {
            dispatchEvent( new Event( BitmapClient.INITIALIZED ) );
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
            }
            catch(e:Error) { TraceError(e); }
            finally
            {
                message = null;
            }
        }
        
        /**
         * Clean up all of this stuff. 
        **/
        public override function Shutdown() : void
        {
            super.Shutdown();
            if( null != bmCurr )
            {
                bmCurr.Dispose();
                bmCurr = null;
            }
            dispatchEvent( new Event( BitmapClient.DISPOSED ) );
        }
    }
}
