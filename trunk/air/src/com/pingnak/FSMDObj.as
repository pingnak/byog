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
    public class FSMDObj extends FSM
    {

        /**
         * Create a finite state machine, based on some source of heartbeats
         * @param fsmthis DisplayObject derived object whose state this is calling
        **/
        public function FSMDObj( fsmthis : DisplayObject )
        {
            super( fsmthis, DObjStart, DObjStop );
        }
        
        /**
         * Heartbeat function
        **/
        public override function Heartbeat(e:Event=null) : void
        {
            if( null == fsm_this.stage )
            {
// If we removed something from the stage, but there is still a heartbeat, stop that.  It's an error.
// Be sure to add some cleanup whenever you permanently remove something from stage
CONFIG::DEBUG { debug.ThrowAssert( "FSMDObj not on stage, and not idle:", fsm_this.name ); }
                if( fsm_this is MovieClip )
                {
                    var mc : MovieClip = fsm_this as MovieClip;
                    MCE.Disable(mc);
                    MCM.Stop(mc);
                    mc.stop();
                }
                DObjStop();
                return;
            }
            super.Heartbeat(e);
        }
    
        /** @private Start ENTER_FRAME heartbeat */
        protected final function DObjStart() : void
        {
            fsm_this.removeEventListener( Event.ENTER_FRAME, Heartbeat );
            fsm_this.addEventListener( Event.ENTER_FRAME, Heartbeat );
        }

        /** @private Stop ENTER_FRAME heartbeat */
        protected final function DObjStop() : void
        {
            fsm_this.removeEventListener( Event.ENTER_FRAME, Heartbeat );
        }

    }
}

