package com.worker
{
    import flash.system.*;
    import flash.concurrent.*;
    import flash.utils.*;
    import flash.events.*;
    import flash.display.*;
    import flash.geom.*;

    import com.pingnak.ByteArrayPool;
    
    // Shared constants
    import com.pingnak.WorkerPackData;

    /**
     *  Worker thread
     *
     *  Pass a shareable ByteArray from render of game state
     *  Generate solid frame or delta frame
     *  uuencode result, return it
     * 
     * http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/system/Worker.html
     * http://help.adobe.com/en_US/as3/dev/WS0191790375a6482943a72da3138ec8eec7e-8000.html
    **/
    public class WorkerPack extends Sprite
    {
        /** When we Trace, this string is added to trace output */
        private var control_mask  : uint = 0;
        private var compressionData:* = null;
        private var compressionText: String = "";
        
        /** Current image */
        private var bmCurr : BitmapData;
        private var bmPrev : BitmapData;

        /** A place to keep our I/O ByteArrays around in, and reuse them */
        private var baPool : ByteArrayPool;

        /** A place to keep our compressor ByteArrays around in, and reuse them */
        private var baPoolPack : ByteArrayPool;
        
        /** Wait for inputs */
        private var initToDo:MessageChannel;
        private var initialized:MessageChannel;
        private var destructToDo:MessageChannel;
        private var destroyed:MessageChannel;
        
        private var frameToDo:MessageChannel;
        private var frameDone:MessageChannel;

        /** Bounding box for incremental updates */
        private var rBounds : Rectangle;

        public function WorkerPack()
        {
            baPool = new ByteArrayPool(4,true,false);
            baPoolPack = new ByteArrayPool(2,false,false);

            // Note: Order is important.  If a message is already in 'todo', it may trigger instantly.
            initialized = Worker.current.getSharedProperty("initialized") as MessageChannel;
            initToDo = Worker.current.getSharedProperty("initToDo") as MessageChannel;
            initToDo.addEventListener(Event.CHANNEL_MESSAGE, InitToDo);

            destroyed = Worker.current.getSharedProperty("destroyed") as MessageChannel;
            destructToDo = Worker.current.getSharedProperty("destructToDo") as MessageChannel;
            destructToDo.addEventListener(Event.CHANNEL_MESSAGE, DestructToDo);
            
            frameDone = Worker.current.getSharedProperty("frameDone") as MessageChannel;
            frameToDo = Worker.current.getSharedProperty("frameToDo") as MessageChannel;
            frameToDo.addEventListener(Event.CHANNEL_MESSAGE, FrameToDo);            
        }
        
        /**
         * Initialize, once we know how big to make buffers
         * Also, re-initialize when we change resolutions
         *
         * Parameters in baReceive:
         *      control_mask, a mask of preferences to control the render
         *      quality, 0/1 for PNG, 0-100 for JPEG
         *      width, height of render bitmap
         *
        **/
        private function InitToDo(e:Event):void
        {
            var baReceive : ByteArray = initToDo.receive() as ByteArray;
CONFIG::DEBUG { trace("*InitToDo:",baReceive.length); }

            if( null != bmCurr )
            {
                bmCurr.dispose();
                bmCurr = null;
            }
            if( null != bmPrev )
            {
                bmPrev.dispose();
                bmPrev = null;
            }

            // Passing in params to set this up
            var id  : uint = baReceive.readUnsignedInt();
            control_mask = baReceive.readUnsignedInt();
            var quality : uint = baReceive.readUnsignedInt();

            // Initialize our bitmaps, according to the parameters
            if( 0 != (WorkerPackData.bJPEG & control_mask) )
            {
                if( quality > 100 )
                    quality = 100;
                compressionData = new JPEGEncoderOptions(quality);
                compressionText = WorkerPackData.EncoderFormatJPEG;
            }
            else // WorkerPackData.bPNG
            {
                compressionData = new PNGEncoderOptions(0 != quality);
                compressionText = WorkerPackData.EncoderFormatPNG;
            }
            /*
            bmCurr = new BitmapData(wide,high,0 != (WorkerPackData.bTransparent & control_mask),0);
            if( 0 != (WorkerPackData.bDelta & control_mask) )
            {
                bmPrev = new BitmapData(wide,high,0 != (WorkerPackData.bTransparent & control_mask),0);
            }
            */

            // Ultimately send data back in the buffer we were given
CONFIG::DEBUG { trace("*InitDone:"); }
            baReceive.position = 0;
            initialized.send(baReceive);
            
        }
        
        /**
         * Handle doomsday message
         * Clean up our pool and bitmaps
        **/
        private function DestructToDo(e:Event):void
        {
CONFIG::DEBUG { trace("*DestructToDo!"); }
            destructToDo.receive();

            // Clean up our 'dead' message queues
            initToDo.removeEventListener(Event.CHANNEL_MESSAGE, InitToDo);
            destructToDo.removeEventListener(Event.CHANNEL_MESSAGE, DestructToDo);
            frameToDo.removeEventListener(Event.CHANNEL_MESSAGE, FrameToDo);
            while( frameToDo.messageAvailable )
                frameToDo.receive();
            destructToDo.close();
            initToDo.close();
            initialized.close();
            frameToDo.close();

            if( null != bmCurr )
            {
                bmCurr.dispose();
                bmCurr = null;
            }
            if( null != bmPrev )
            {
                bmPrev.dispose();
                bmPrev = null;
            }
            
            baPool.Flush();
            baPool = null;
            
            baPoolPack.Flush();
            baPoolPack = null;
CONFIG::DEBUG { trace("*Doom!"); }
            
            // Send a nothing message to let us know we're gone
            destroyed.send(null);

            // Prompt garbage collection on all of these bitmaps and buffers
            // BitmapClient.as does it too, but that's on a different copy of the interpreter
            System.pauseForGCIfCollectionImminent();
            
            // Should never return...
            Worker.current.terminate();
CONFIG::DEBUG { trace("*Doomy-doom!"); }// If you see this, something's horribly wrong....
        }

        /**
         * Generate Frame
         * Parameters in baReceive: 
         *      left, top, wide, high - bounding box to clip compression 
        **/
        private function FrameToDo(e:Event):void
        {
            var baReceive : ByteArray = frameToDo.receive() as ByteArray;
//CONFIG::DEBUG { trace("*FrameToDo:",baReceive.length); }
            var baRespond : ByteArray = null;
            var bytes : ByteArray = null;
            var diff : BitmapData = null;
            var dBoundsIn : Rectangle;
            var dBounds : Rectangle;
            var pBounds : Point;
            try
            {
                // Create a delta frame 
                baReceive.position = 0;
                var id   : uint = baReceive.readUnsignedInt();
                var left : uint = baReceive.readUnsignedInt();
                var top  : uint = baReceive.readUnsignedInt();
                var wide : uint = baReceive.readUnsignedInt();
                var high : uint = baReceive.readUnsignedInt();
                dBoundsIn = new Rectangle(left,top,wide,high);

                if( null == bmCurr || bmCurr.width != wide || bmCurr.height != high )
                {
                    if( null != bmCurr )
                        bmCurr.dispose();
                    bmCurr = new BitmapData(wide,high,0 != (WorkerPackData.bTransparent & control_mask),0);
                }
                bmCurr.setPixels( dBoundsIn, baReceive );

                baRespond = baPool.New();
            
                if( 0 != (WorkerPackData.bDelta & control_mask) )
                {   
                    // Do delta frames on solid background that is unchanging
                    // Is no better that 'solid I-frames', when solid content scrolls, or does things '3D'
                    // Compare with prior render to get differences.  
                    if( null == bmPrev || bmPrev.width != wide || bmPrev.height != high )
                    {
                        if( null != bmPrev )
                            bmPrev.dispose();
                        bmPrev = new BitmapData(wide,high,0 != (WorkerPackData.bTransparent & control_mask),0);
                    }

                    // This allocates a bitmap (wasteful), but is super fast compared to script
                    diff = bmCurr.compare(bmPrev) as BitmapData;
                    if( null == diff )
                    {   // No differences: Nothing to send.
                        baRespond.writeInt(id);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
CONFIG::DEBUG {         trace("*Null diff"); }
                    }
                    else
                    {
                        if( 0 != (WorkerPackData.bMinimum & control_mask) )
                        {   // Find the minimum area required to update
                            dBounds = diff.getColorBoundsRect(0xff000000, 0, false);
                            pBounds = dBounds.topLeft;
                        }
                        else
                        {   // Update whole thing
                            dBounds = diff.rect;
                            pBounds = dBounds.topLeft;
                        }
                        if( dBoundsIn.intersects(dBounds) )
                        {
                            dBounds = dBoundsIn.intersection(dBounds);
                            
                            // Turn pixels that are identical (according to compare) to transparent black; copy non-identical
                            diff.threshold(diff,dBounds, pBounds, "==",0,0,0x00ffffff,false);
                            
                            // Now use the alpha channel we created to copy 'new' (visible) pixels across, rather than the differences left from 'compare'
                            diff.copyPixels(bmCurr,dBounds, pBounds,diff, pBounds, true );
                
                            // Return our PNG encoded byte array; either into one given, or a new one
                            // Current can now be overwritten by next render
                            bytes = baPoolPack.New();
                            diff.encode(dBounds,compressionData, bytes);
                            bytes.length = bytes.position;
                            bytes.position = 0;
            
                            // Write out bounding box
                            baRespond.writeInt(id);
                            baRespond.writeInt(dBounds.left);
                            baRespond.writeInt(dBounds.top);
                            baRespond.writeInt(dBounds.width);
                            baRespond.writeInt(dBounds.height);
                            if(0 != (WorkerPackData.bBase64 & control_mask))
                            {
                                baRespond.writeUTFBytes(compressionText);
                                BytesToBase64( baRespond, bytes );
                            }
                            else
                            {
                                baRespond.writeBytes( bytes );
                            }
                        }
                        else
                        {
                            baRespond.writeInt(id);
                            baRespond.writeInt(0);
                            baRespond.writeInt(0);
                            baRespond.writeInt(0);
                            baRespond.writeInt(0);
//CONFIG::DEBUG {             trace("*Empty", bmCurr.rect, dBounds, dBoundsIn); }
                        }

                    }
        
                    // Swap previous and current
                    var bmTmp : BitmapData = bmCurr;
                    bmCurr = bmPrev;
                    bmPrev = bmTmp;
                }
                else
                {
                    // Get a bounding box around visible portion of the refresh, to make some things quicker
                    // We don't encode difference outside this box, because 'different' is invisible (alpha=0)
                    if( 0 != (WorkerPackData.bMinimum & control_mask) )
                    {   // Find the minimum area required to update
                        dBounds = bmCurr.getColorBoundsRect(0xff000000, 0, false);
                    }
                    else
                    {   // Update whole thing
                        dBounds = bmCurr.rect;
                    }
                    if( dBoundsIn.intersects(dBounds) )
                    {
                        dBounds = dBoundsIn.intersection(dBounds);
                        bytes = baPoolPack.New();
                        bmCurr.encode(dBounds,compressionData,bytes);
                        bytes.length = bytes.position;
                        bytes.position = 0;
                        
                        baRespond.writeInt(id);
                        baRespond.writeInt(dBounds.left);
                        baRespond.writeInt(dBounds.top);
                        baRespond.writeInt(dBounds.width);
                        baRespond.writeInt(dBounds.height);
                        if(0 != (WorkerPackData.bBase64 & control_mask))
                        {
                            baRespond.writeUTFBytes(compressionText);
                            BytesToBase64( baRespond, bytes );
                        }
                        else
                        {
                            baRespond.writeBytes( bytes );
                        }
                    }
                    else
                    {   // Write blank png
                        baRespond.writeInt(id);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
                        baRespond.writeInt(0);
//CONFIG::DEBUG {         trace("*Empty2", bmCurr.rect, dBounds, dBoundsIn); }
                    }

                    // Ultimately send data back in the buffer we were given
                    baRespond.length = baRespond.position;
                    baRespond.position = 0;
                    if( MessageChannelState.OPEN == frameDone.state )
                    {
                        frameDone.send(baRespond);
                    }
                }
            }
            catch(e:Error) { trace("FrameToDo Error:",e.toString()); }
            finally
            {
                // Whatever happens, don't leak this stuff.  It gets expensive, real fast.
                baPoolPack.Delete(bytes);
                bytes = null;
                baPool.Delete(baRespond);
                baRespond = null;
                baReceive = null;
                if( null != diff )
                {
                    diff.dispose();
                    diff = null;
                }
            }
        }
        

        /**
         * Encode data to Base64 format
         * @param baDst ByteArray to receive Base64 data, at current position 
         * @param baSrc ByteArray to encode
        **/
        public static function BytesToBase64( baDst:ByteArray, baSrc:ByteArray ) : void
        {
            //const encodes : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            const encodes : Vector.<int> = new <int>[
                65,66,67,68,69,70,71,72,73,74,  // A-Z
                75,76,77,78,79,80,81,82,83,84,
                85,86,87,88,89,90,
                 97, 98, 99,100,101,102,103,104,105,106, //a-z
                107,108,109,110,111,112,113,114,115,116,
                117,118,119,120,121,122,
                48,49,50,51,52,53,54,55,56,57, // 0-9
                43,47]; // +/
            var saved : uint = baSrc.position;
            var remains : uint = baSrc.length;
            baSrc.position = 0;
            // Grow destination with a bit of room to spare
            baDst.length = Math.max( baDst.length, baDst.position + Math.ceil((2 + remains - ((remains + 2) % 3)) * 4 / 3) );
            var index : int = baDst.position;
            var shift : uint;
            while( 3 <= remains )
            {
                shift =  (baSrc.readByte()&0xff) << 16;
                shift |= (baSrc.readByte()&0xff) << 8;
                shift |= (baSrc.readByte()&0xff);
                baDst[index++] = encodes[shift>>>18];
                baDst[index++] = encodes[(shift>>>12) & 0x3f];
                baDst[index++] = encodes[(shift>>>6) & 0x3f];
                baDst[index++] = encodes[shift & 0x3f];
                remains -= 3;
            }
            if( 2 == remains )
            {
                shift =  (baSrc.readByte()&0xff) << 16;
                shift |= (baSrc.readByte()&0xff) << 8;
                baDst[index++] = encodes[shift>>>18];
                baDst[index++] = encodes[(shift>>>12) & 0x3f];
                baDst[index++] = encodes[(shift>>>6) & 0x3f];
                baDst[index++] = 61;// '='
            }
            else if( 1 == remains )
            {
                shift = (baSrc.readByte()&0xff) << 16;
                baDst[index++] = encodes[shift>>>18];
                baDst[index++] = encodes[(shift>>>12) & 0x3f];
                baDst[index++] = 61;// '=='
                baDst[index++] = 61;
            }
            // Trim destination to what it now contains
            baSrc.position = saved;
            baDst.position = index;
       }


    }
}
