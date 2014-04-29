package com.pingnak
{
    import flash.utils.*;
    import flash.display.MovieClip;
    
    /**
     * A simple pool of some kind of class
     *
     * Keeps scratch allocations under control, so housekeeping is smoother
    **/
    public class MCPool extends Pool
    {
        /**
         * Make a pool of some kind of MovieClips
         * @param t Type of class to keep in pool
         * @param depth How many to put in pool
         * @param bGrow Whether to make new things when the pool runs out
         * @newFunction Optional initialization to do on objects
         * @deleteFunction Optional clean-up to do on objects
        **/
        public function MCPool(t:Class,depth:uint=0,bGrow:Boolean = true,newFunction:Function=null,deleteFunction:Function=null)
        {
            if( null == deleteFunction )
            {
                deleteFunction = StopIt;
            }
            super(t,depth,bGrow,newFunction,deleteFunction,StopIt,StopIt)
        }
        
        /**
         * When we make things for the pool, or free them, perform some cleanups on them
        **/
        private static function StopIt(mc:MovieClip):void
        {
            if( null != mc )
            {
                if( null != mc.stage )
                    mc.parent.removeChild(mc);
                //EventDB.RemoveListeners(mc);
                MCE.Disable(mc);
                MCM.Stop(mc);
                mc.stop();
            }
        }
    }
}
