package com.pingnak
{
    import flash.utils.ByteArray;
    /**
     * A pool of shareable ByteArray Objects
     *
     * Keeps scratch allocations under control, so housekeeping is smoother
     *
     * NOTE:    BA returned by New has a DELIBERATELY unpredictable length.  
     *          SET the length when you have written data to it.
     *          That's what the 'ba.length=ba.position' is about.
    **/
    public class ByteArrayPool extends Pool
    {
        // Should this be shareable byte arrays?
        private var shareable : Boolean;

        /**
         * Make a pool of ByteArrays
         * @param depth How many to put in pool
         * @param bGrow Whether to make new things when the pool runs out
        **/
        public function ByteArrayPool( depth:uint = 0, shareable:Boolean = true, bGrow:Boolean = true )
        {
            this.shareable = shareable;
            super(ByteArray,depth,bGrow,NewBA,DeleteBA,CreateBA,DestroyBA);
        }
        
        /**
         * @private
         * Initialize a ByteArray, as it's being handed off to be used.
        **/
        private function NewBA(ba:ByteArray):void
        {
            // Reset position
            ba.position = 0;
            
            // Length is whatever was already allocated within it.
            
            // Clearing it would potentially the memory we want to REUSE, not 
            // have dumped into (and potentially forgotten by) the AS mark and 
            // sweep.
            //trace("NewBA",ba.shareable,ba.position,ba.length);
        }

        /**
         * @private
         * Clean up a ByteArray, as it's being deleted
        **/
        private function DeleteBA(ba:ByteArray):void
        {
            // As it so happens, we don't do anything with it
            //trace("DeleteBA",ba.shareable,ba.position,ba.length);
        }
        
        /**
         * @private
         * Initialize a ByteArray, as it's being initially created in the pool
        **/
        private function CreateBA(ba:ByteArray):void
        {
            ba.shareable = shareable;
            //trace("CreateBA",ba.shareable,ba.position,ba.length);
        }

        /**
         * @private
         * Destroy a ByteArray, when the pool is destroyed
        **/
        private function DestroyBA(ba:ByteArray):void
        {
            //trace("DestroyBA",ba.shareable,ba.position,ba.length);
            ba.clear();
        }
         
    }
}