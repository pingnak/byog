
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    import flash.geom.*;
    import flash.events.*;
    import flash.net.*;
    import flash.display.*;
    import com.pingnak.*;

    /**
     * Manage the compression Worker class.
    **/
    public class BitmapClient extends EventDispatcher
    {
        private static var idCurr : int = 0;

        /** Worker has to be a swf.  */
        [Embed(source="../worker/worker.swf", mimeType="application/octet-stream")] 
        private static const BAWorker:Class;
        internal static function get BABackgroundWorker() : ByteArray { return new BAWorker(); }

        /** Our little worker bee */
        private var bgWorker : Worker;
        
        /* Inputs and outputs to/from worker */
        private var initToDo:MessageChannel;
        protected var initialized:MessageChannel;

        private var destructToDo:MessageChannel;
        private var destroyed:MessageChannel;

        private var frameToDo:MessageChannel;
        protected var frameDone:MessageChannel;

        private var httpframeToDo:MessageChannel;
        protected var frameDoneHTTP:MessageChannel;
        
        /** Pool of messenger ByteArray objects */
        protected var baPoolShared : ByteArrayPool;
        
        /** Keep track of initialized state in an easy query */
        protected var bWorkerInitialized : Boolean = false;

        /** Control mask we gave to worker */
        protected var control_mask  : uint = 0;

        private var queue : Array;

        public function get ready() : Boolean
        {
            return bWorkerInitialized && !frameToDo.messageAvailable;
        }

        
        public function BitmapClient()
        {
            queue = new Array();
        }

        /**
         * Figure out how to adapt to client screen
        **/
        public function InitWorker( cbDone : Function, mask:uint = WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bMinimum | WorkerPackData.bBase64, quality:uint = 1 ) : void
        {
CONFIG::DEBUG { debug.Trace("InitWorker"); }
            
            control_mask= mask;
            
            if( null == bgWorker )
            {
                baPoolShared = new ByteArrayPool(6,true,false);

                bgWorker = WorkerDomain.current.createWorker(BABackgroundWorker);
    
                // Initialization
                initToDo   = Worker.current.createMessageChannel(bgWorker);
                bgWorker.setSharedProperty("initToDo", initToDo);
                initialized= bgWorker.createMessageChannel(Worker.current);
                bgWorker.setSharedProperty("initialized", initialized);
                initialized.addEventListener(Event.CHANNEL_MESSAGE, InitializedWorker);

                // Destruction
                destructToDo  = Worker.current.createMessageChannel(bgWorker);
                bgWorker.setSharedProperty("destructToDo", destructToDo);
                destroyed= bgWorker.createMessageChannel(Worker.current);
                bgWorker.setSharedProperty("destroyed", destroyed);
                destroyed.addEventListener(Event.CHANNEL_MESSAGE, DestroyedWorker);
                
                // Receive completions here
                frameDone = bgWorker.createMessageChannel(Worker.current);
                bgWorker.setSharedProperty("frameDone", frameDone);
                frameDone.addEventListener(Event.CHANNEL_MESSAGE, RenderDone);

                // Compress a transparent png, and Base64 encode it
                frameToDo = Worker.current.createMessageChannel(bgWorker);
                bgWorker.setSharedProperty("frameToDo", frameToDo);
    
                // Compress a transparent png
                httpframeToDo = Worker.current.createMessageChannel(bgWorker);
                bgWorker.setSharedProperty("httpframeToDo", httpframeToDo);
    
                // Tell worker to initialize its self.  Wait for initialized response
                bgWorker.start();
            }
            
            var baEncode : ByteArray = baPoolShared.New();
            // Add it to task queue
            ++idCurr;
            queue[idCurr] = { cb:cbDone, ba:baEncode };
            baEncode.writeInt(idCurr);
            baEncode.writeInt(mask);
            baEncode.writeInt(quality);
            baEncode.length = baEncode.position;
            initToDo.send(baEncode);
        }

        protected function InitializedWorker(e:Event) : void
        {
CONFIG::DEBUG { debug.Trace("InitializedWorker"); }
            var message : ByteArray = initialized.receive() as ByteArray;
            message.position = 0;
            var id  : uint = message.readUnsignedInt();

            var cbo : Object = queue[id];
            delete queue[id];
            if( null == cbo )
            {
                debug.TraceError( "InitializedWorker Callback ID not found.", id );
                return;
            }

            // Call back our render-complete function
            baPoolShared.Delete(cbo.ba);
            bWorkerInitialized = true;
            cbo.cb();
        }
        
        /**
         * Render Base64 PNG for client refresh
         * @return true if the task was passed to thread
        **/
        public function RenderToDo( cbDone : Function, bm:BitmapData, rect : Rectangle = null ):Boolean
        {
            if( !ready )
                return false;
            if( null != rect )
            {
                // We should have bounds inside what can be rendered
CONFIG::DEBUG { debug.Assert( bm.rect.intersects(rect), rect, bm.rect ); }
                rect = rect.intersection(bm.rect);
            }
            else
            {
                rect = bm.rect;
            }
            if( 0 == rect.width )
            {
                return false;
            }
            try
            {
                // Add it to task queue
                var baEncode : ByteArray = baPoolShared.New();
                ++idCurr;
                queue[idCurr] = { cb:cbDone, ba:baEncode };
                baEncode.writeInt(idCurr);
                baEncode.writeInt(rect.left);
                baEncode.writeInt(rect.top);
                baEncode.writeInt(rect.width);
                baEncode.writeInt(rect.height);
                bm.copyPixelsToByteArray(rect, baEncode);
                baEncode.length = baEncode.position;
                baEncode.position = 0;
                frameToDo.send(baEncode);
                baEncode = null;
                return true;
            }
            catch(e:Error) 
            { 
                if( null != baEncode )
                {
                    baPoolShared.Delete(baEncode);
                    delete queue[idCurr];
                }
                debug.TraceError(e); 
            }
            // Add it to task queue
            baEncode = null;
            return false;
        }

        /**
         * Worker thread has finished a compression job
         * Override this, or use RenderHandler, your choice 
        **/
        protected function RenderDone(e:Event):void
        {
            var message : ByteArray = frameDone.receive() as ByteArray;
            message.position = 0;
            
            // Data follows
            var id   : uint = message.readUnsignedInt();
            var left : uint = message.readUnsignedInt();
            var top  : uint = message.readUnsignedInt();
            var wide : uint = message.readUnsignedInt();
            var high : uint = message.readUnsignedInt();
            var bounds : Rectangle = new Rectangle(left,top,wide,high);

            var cbo : Object = queue[id];
            delete queue[id];
            if( null == cbo )
            {
                debug.TraceError( "RenderDone Callback ID not found.", id );
                message = null;
                return;
            }

            // Call back our render-complete function
            cbo.cb.call( null, bounds, message );
            baPoolShared.Delete(cbo.ba);
            message = null;
        }

        /**
         * We have been closed.
        **/
        public function Shutdown() : void
        {
            bWorkerInitialized = false;
            
            // Clear out pending tasks
            var id : int;
            var cbo : Object;
            for( id in queue )
            {
                cbo = queue[id];
                delete queue[id];
                baPoolShared.Delete(cbo.ba);
                cbo.cb = null;
            }
            queue = null;

            // Clean up event listeners
            bWorkerInitialized = false;
            if( null != frameDone )
            {
                frameDone.removeEventListener(Event.CHANNEL_MESSAGE, RenderDone);
                frameDone = null;
            }
            if( null != initialized )
            {
                initialized.removeEventListener(Event.CHANNEL_MESSAGE, InitializedWorker);
                initialized = null;
            }

            // Kill our worker thread in a little while; 
            // Attempting to prevent a deadlock condition, when this is destroyed
            // OR it may be crashing: error handling on Worker threads in Flash is flaky
            if( null != bgWorker )
            {
                setTimeout(KillWorker,250);
            }
       }
        
        /** @private Timeout to kill worker*/
        private function KillWorker() : void
        {
            // Add it to task queue
            destructToDo.send(null);
            bgWorker = null;
        }
        
        /** @private Worker has done seppuku */
        private function DestroyedWorker(e:Event) : void
        {
            destroyed.receive();
            destroyed.removeEventListener(Event.CHANNEL_MESSAGE, DestroyedWorker);
            destroyed = null;

            baPoolShared.Flush();
            baPoolShared = null;

            // Prompt garbage collection on all of these bitmaps and buffers
            System.pauseForGCIfCollectionImminent();
       }
                
   }
}