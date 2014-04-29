package com.pingnak
{
    import flash.utils.*;
    
    /**
     * A simple free of some kind of class
     *
     * Keeps scratch allocations under control, so housekeeping is smoother
    **/
    public class Pool
    {
        // What type of things to keep here
        protected var T : Class;
        
        // Where to keep them, until needed
        protected var free : Array;

        // DEBUG: Keep track of the ones in use, too
        protected var used : Dictionary;
        
        // If we run out of free, should we make more?
        protected var bGrow : Boolean;

        // Function to initialize new free members
        protected var newFunction : Function;
        
        // Function to reset free members
        protected var deleteFunction : Function;
        
        // Function to initialize new free members
        protected var createFunction : Function;
        
        // Function to initialize new free members
        protected var destroyFunction : Function;
        
        /**
         * Make a free of T
         * @param t Type of class to keep in free
         * @param depth How many to put in free
         * @param bGrow Whether to make new things when the free runs out
         * @param newFunction Something to call to initialize each time an object is about to be returned by New
         * @param deleteFunction Something to call to destroy an object, each time it is given to Delete.
         * @param createFunction Something to do ONCE when a pool object is created
         * @param destroyFunction Something to do ONCE when a pool object is destroyed, with the pool
        **/
        public function Pool(t:Class,depth:uint=0,bGrow:Boolean = true,newFunction:Function=null,deleteFunction:Function=null,createFunction:Function=null,destroyFunction:Function=null)
        {
            this.T = t;
            this.bGrow = bGrow;
            this.newFunction =      null == newFunction     ? Pool.DoNothing : newFunction;
            this.deleteFunction =   null == deleteFunction  ? Pool.DoNothing : deleteFunction;
            this.createFunction =   null == createFunction  ? Pool.DoNothing : createFunction;
            this.destroyFunction =  null == destroyFunction ? Pool.DoNothing : destroyFunction;
            this.used = new Dictionary();
            free = new Array();
            while( 0 < depth-- )
            {
                var i : * = new T();
                createFunction(i);
                free.push( i );
            }
        }
        
        /**
         * Reuse an object, or get a new one
        **/
        public function New() : *
        {
CONFIG::DEBUG { debug.Assert( null != free, "New from dead pool", this ); }

            // Pop oldest free object.
            var instance : Object = free.shift();
            if( null == instance )
            {
                if( bGrow )
                {
                    instance = new T();
                    createFunction(instance);
                }
                else
                {
CONFIG::DEBUG { debug.ThrowAssert( "Empty Pool" ); }
                    return null;
                }
            }
            // Keep track of where leaks came from
CONFIG::RELEASE{used[instance] = true;}
CONFIG::DEBUG  {used[instance] = (new Error().getStackTrace());}
            newFunction(instance);
            return instance;
        }
        
        /**
         * Put an object back into the free, for reuse
        **/
        public function Delete( instance:* ) : void
        {
CONFIG::DEBUG { debug.Assert( null != free, "Delete to dead pool", this, instance ); }
            if( null != instance )
            {
                // Should not already be 'free'
CONFIG::DEBUG { 
                // Same type as original
                if( getQualifiedClassName(T) != getQualifiedClassName(instance) )
                {
                    debug.ThrowAssert( getQualifiedClassName(instance), "Pool: Bad Delete", getQualifiedClassName(T), instance );
                    return;
                }
                if( -1 != free.indexOf(instance) )
                {
                    debug.ThrowAssert( "Already Freed" );
                    return;
                }
                if( !(instance in used) )
                {
                    debug.ThrowAssert( "Not from this pool" );
                    return;
                }
}
                // Remove from used pool... if it came from this
                if( instance in used )
                {
                    delete used[instance];
                }
                else
                {
                    return;
                }
                free.push(instance);
                deleteFunction(instance);
            }
        }

        /**
         * How much is in the free
        **/
        public function get available() : uint
        {
            return free.length;
        }
        
        /**
         * Forget the free
        **/
        public function Flush() : void
        {
            var curr : *;
            for( curr in used )
            {
                deleteFunction(curr);
                free.push(curr);
                // Stuff at this point may still be 'in use', and that could be 'bad'.  So tell us.
CONFIG::DEBUG { debug.Trace("LEAKED",getQualifiedClassName(T)+'?\n',used[curr]); }
            }
            while( 0 != free.length )
            {
                curr = free.shift();
                delete used[curr];
                destroyFunction(curr);
            }
            free = null;
            used = null;
        }
        
        /** Do-nothing stand-in for unused functions */
        protected static function DoNothing( obj:* ) : void
        {
        }
    }
}
