package com.pingnak
{
    import flash.utils.Dictionary;
    import flash.events.EventDispatcher;
    /**
     * This is a database of event listeners.
     *
     * It allows us to strip objects of event listeners without knowing all of the 
     * functions and event types, some of which might be private or local functions.
     *
     * Nothing worse than grabbing something from a pool, and having references to stale callbacks
    **/
    public class EventDB
    {
        // A dictionary of objects, to dictionaries of event types, to arrays of functions
        private static var db : Dictionary = new Dictionary();
        
        /**
         * Add an event to an EventDispatcher
         * @param obj Object to listen 
         * @param type, listener, etc. are all from EventDispatcher.addEventListener
        **/
        public static function AddListener( obj:EventDispatcher, type:String, listener : Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false ) : void
        {
            if( null == obj )
                return;
            var dbListen : Dictionary = db[obj];
            if( null == dbListen )
            {
                dbListen = new Dictionary();
                db[obj] = dbListen;
            }
            var aListen : Array = dbListen[type];
            if( null == aListen )
            {
                aListen = new Array();
                dbListen[type] = aListen;
            }
            aListen.push(listener);
            obj.addEventListener( type, listener, useCapture, priority, useWeakReference );
        }

        
        /**
         * Clear some or all events from an object
         * @param ed Object to clean up; if not an EventDispatcher, we don't clean it up
         * @param type Event type to clean up; all if not set
         * @param listener Particular event to clean up; all of type, if not set
        **/
        public static function RemoveListener(ed:*, type:String = null, listener : Function = null ) : void
        {
            var obj : EventDispatcher = ed as EventDispatcher;
            if( null == obj )
                return;
            var dbListen : Dictionary;
            var aListen  : Array;
            var callback  : Function;
            if( null == type )
            {
                RemoveListeners(obj);
                return;
            }
            if( null == listener )
            {
                dbListen = db[obj];
                if( null == dbListen )
                    return;
                aListen = dbListen[type] as Array;
                while( 0 != aListen.length )
                {
                    callback = aListen.pop();
                    obj.removeEventListener( type, callback, false );
                    obj.removeEventListener( type, callback, true );
                }
                delete dbListen[type];
            }
            else
            {
                dbListen = db[obj];
                if( null != dbListen )
                {
                    aListen = dbListen[type] as Array;
                    if( null != aListen )
                    {
                        var i : int = aListen.indexOf(listener);
                        if( -1 != i )
                        {
                            aListen.splice(i,1);
                        }
                        if( 0 == aListen.length )
                        {
                            delete dbListen[type];
                        }
                    }
                }
                obj.removeEventListener( type, listener, false );
                obj.removeEventListener( type, listener, true );
            }
            
            // Determine if dbListen is zero length
            var key : *;
            for( key in dbListen )
            {
                return; // Still has something attached to it.
            }
            // Remove reference
            delete db[obj];
        }

        /**
         * Remove all event handlers from an object that is nominally 'free'
         * @param ed Any kind of object; will return harmlessly if not an EventDispatcher
        **/
        public static function RemoveListeners( ed:* ) : void
        {
            var obj : EventDispatcher = ed as EventDispatcher;
            if( null == obj )
                return;
            var dbListen : Dictionary = db[obj];
            if( null == dbListen )
                return;
            var aListen  : Array;
            var callback  : Function;
            var type : *;
            var aClean : Array = new Array();
            for( type in dbListen )
            {
                aListen = dbListen[type] as Array;
                aClean.push(aListen);
                while( 0 != aListen.length )
                {
                    callback = aListen.pop();
                    obj.removeEventListener( type, callback, false );
                    obj.removeEventListener( type, callback, true );
                }
            }
            while( 0 != aClean.length )
            {
                delete dbListen[aClean.pop()];
            }
            delete db[obj];
        }

        /**
         * Clear ALL events from ALL objects touched by this
         * Useful when restarting
        **/
        public static function Reset() : void
        {
            var key : *;
            for( key in db )
            {
                RemoveListeners(key);
            }
        }
    }
}
