/**
 * Class implementing generic FSM slave class
 *
 * This requires an object to hook into, which will serve as its master
**/

package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Finite State Machine
    **/
    public class FSM
    {
        /**
         * State machine idle ID
        **/
        public static const IDLE : String = "Idle";

        /**
         * State machine database.
         * Though making it a dictionary would be faster for stop/start, that 
         * happens infrequently.  What happens constantly is running through 
         * the list of all of these, and calling heartbeat on them, with the
         * possibility that the container will be modified (go idle).  This 
         * buggers Dictionary iteration, and so I'd have to make arrays to 
         * keep track, anyway.
        **/
        protected static const fsm_all : Vector.<FSM> = new Vector.<FSM>();
        
        /**
         * @private Current state of FSM
        **/
        protected var fsm_state : String = IDLE;

        /**
         * @private Where to find FSM state functions; this allows us to 
         * implement multiple FSM on one object, or get around the lack of
         * AS3 multiple inheritance
        **/
        protected var fsm_this : Object;

        /**
         * @private State machine stack
        **/
        protected var fsm_stack : Vector.<String>;
    
        /**
         * @private Heartbeat starter - For any state besides IDLE
        **/
        protected var fsm_start : Function;

        /**
         * @private Heartbeat stopper - for idle state, so this doesn't nibble away at our CPU
        **/
        protected var fsm_stop  : Function;

        /**
         * Main cycle for global/default FSMs.
         * Hook it to whatever.  Probably stage.ENTER_FRAME.
         * 
        **/
        public static function Cycle(e:Event=null) : void
        {
            var fsm : FSM;
            var curr : int = fsm_all.length;
            while( 0 < curr-- )
            {
                fsm = fsm_all[curr];
                fsm.Heartbeat();
            }
        }

        /**
         * Reset all global/default FSMs
        **/
        public static function Reset() : void
        {
            var fsm : FSM;
            while( 0 < fsm_all.length )
            {
                fsm = fsm_all.pop();
                fsm.fsm_stop = DoNothing;// Prevent search+removal step
                fsm.Reset();
            }
            function DoNothing():void {}
        }
        
        /**
         * Create a finite state machine, based on some source of heartbeats
         * @param fsmthis Object whose state this is calling
         * @param startFunc If we have a custom state starter, this is it
         * @param stopFunc If we have a custom state starter, this is the stopper
        **/
        public function FSM( fsmthis : Object = null, startFunc : Function = null, stopFunc : Function = null )
        {
            fsm_this = null == fsmthis ? this : fsmthis;
            if( null == startFunc )
            {
                fsm_start = DefaultStart;
                fsm_stop  = DefaultStop;
            }
            else
            {   // Custom FSM heartbeat.
                fsm_start = startFunc;
// If we have a start function, we need a stop function
CONFIG::DEBUG { debug.Assert( stopFunc is Function ); }
                fsm_stop = stopFunc;
            }
            Reset();
        }
        
        /**
         * Stop/reset FSM
         * @param e A placeholder to make using this as an event handler easier
        **/
        public function Reset(e:Event=null):void
        {
            state = IDLE;
            fsm_stack = new Vector.<String>();
        }
        
        /**
         * State Setter - check for validity
         * Once state is set
        **/
        public function set state(idFunc : String) : void
        { 
CONFIG::DEBUG { debug.Trace( "state:", this, fsm_this, fsm_state, "->", idFunc ); }
//CONFIG::DEBUG { debug.TraceStack(); }
CONFIG::DEBUG { debug.Assert( IDLE == idFunc || fsm_this[idFunc] is Function ); }
            var oldState : String = fsm_state;
            fsm_state = idFunc;
            if( IDLE == fsm_state )
            {   // Stop Heartbeat 
                fsm_stop();
            }
            else if( IDLE == oldState )
            {   // Start Heartbeat
                fsm_start();
            }
        }
        
        /**
         * Get state
        **/
        public function get state() : String 
        { 
// Invalid state function id 
CONFIG::DEBUG { debug.Assert( IDLE == fsm_state || fsm_this[fsm_state] is Function ); }
            return fsm_state; 
        }
        
        /**
         * Heartbeat function
        **/
        public function Heartbeat(e:Event=null) : void
        {
// Invalid state function id 
CONFIG::DEBUG { debug.Assert( fsm_this[fsm_state] is Function ); }
            if( IDLE == fsm_state )
            {   // Stop Heartbeat calls 
                fsm_stop();
                return;
            }
CONFIG::DEBUG { fsm_this[fsm_state].call(fsm_this); }
CONFIG::RELEASE {
            try
            {
                fsm_this[fsm_state].call(fsm_this);
            }
            catch(e:Error)
            {   // Something is borked, but we caught the exception
                debug.TraceError("FSM.Heartbeat:",fsm_state,fsm_this,e);
                fsm_state = IDLE;
            }
}
        }
    
        /**
         * Get stack depth
        **/
        public function get stackdepth() : int
        {
            return fsm_stack.length;
        }
        
        /**
         * Push something onto end of state machine stack
         * @param idFunc State to remember 
        **/
        public final function FSMPush(idFunc:String):void
        {
// Invalid state function id 
CONFIG::DEBUG { debug.Assert( IDLE == idFunc || fsm_this[idFunc] is Function ); }
            fsm_stack.push(idFunc);
        }
        
        /**
         * Pop state from back stack
        **/
        public final function FSMPop() : void 
        {
            state = fsm_stack.pop();
        }
        
        /**
         * Push something to front of state machine stack
         * @param idFunc State to remember 
        **/
        public final function FSMUnshift(idFunc:String):void
        {
// Invalid state function id 
CONFIG::DEBUG { debug.Assert( IDLE == idFunc || fsm_this[idFunc] is Function ); }
            fsm_stack.unshift(idFunc);
        }
        
        /**
         * Pop state from front of stack
        **/
        public final function FSMShift() : void 
        {
            state = fsm_stack.shift();
        }


        /** @private Start Default heartbeat */
        protected final function DefaultStart() : void
        {
            var i : int = fsm_all.indexOf(this);
            if( -1 == i )
            {
                fsm_all.push(this);
            }
        }
        /** @private Stop Default heartbeat */
        protected final function DefaultStop() : void
        {
            var i : int = fsm_all.indexOf(this);
            if( -1 != i )
            {
                fsm_all.splice(i,1);
            }
        }
    }
}

