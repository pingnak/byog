/**
 * Class implementing generic FSM slave class
 *
 * This requires an object to hook into, which will serve as its master
 *  
**/

package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Finite State Machine
    **/
    public class FSMTimer extends FSM
    {
        var timer : Timer;
        /**
         * Create a finite state machine, based on some source of heartbeats
         * @param fsmthis Object whose state this is calling
         * @param startFunc If we have a custom state starter, this is it
         * @param stopFunc If we have a custom state starter, this is the stopper
        **/
        public function FSMTimer( fsmthis : Object, msDelay : int )
        {
            super(fsmthis,TimerStart,TimerStop);
            timer = new Timer(msDelay);
            timer.addEventListener( TimerEvent.TIMER, Heartbeat );
        }
        
        /** @private Start Timer heartbeat */
        protected final function TimerStart() : void
        {
            timer.start();
        }

        /** @private Stop Timer heartbeat */
        protected final function TimerStop() : void
        {
            timer.reset();
        }

    }
}

