
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    import flash.events.*;
    import flash.display.Loader;
    	import flash.net.Socket;
    import flash.debugger.enterDebugger;
    
    /**
     * Put debug functionality in a can
    **/
    public class debug
    {

	    /** Log levels */
	    public static const LOG_NOTHING     : int = -1;
	    public static const LOG_ERROR       : int = 0;
	    public static const LOG_IMPORTANT   : int = 1;
	    public static const LOG_INFO        : int = 2;
	    public static const LOG_TRIVIA      : int = 3;

CONFIG::DEBUG {
	    public static const LOG_LEVEL : int = LOG_TRIVIA;
}
CONFIG::RELEASE {
	    public static const LOG_LEVEL : int = LOG_IMPORTANT;
}

        /** TextEvent ID to get server log messages */
        public static const DEBUG_LOG : String = "LOGGED";
        
        /** Maximum number of log events to keep */
        public static var LOG_MAX : int = 100;

        /** Log contents */
        private static var logList : Array = new Array();

        private static const ed : EventDispatcher = new EventDispatcher();
        
        public function debug()
        {
        }


        /**
         * Trace common download status events
        **/
        public static function TraceDownload( loader : EventDispatcher ) : void
        {
            if( loader is Loader )
                loader = (loader as Loader).contentLoaderInfo;
            loader.addEventListener( IOErrorEvent.IO_ERROR, Log );
            loader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, Log );
CONFIG::DEBUG {
            loader.addEventListener( Event.OPEN, trace );
            loader.addEventListener( Event.COMPLETE, trace );
            loader.addEventListener( Event.INIT, trace );
            loader.addEventListener( HTTPStatusEvent.HTTP_STATUS, trace );
            // loader.addEventListener( ProgressEvent.PROGRESS, trace );
}
        }
        
        /**
         * Do a hex dump into a String
         * @param ba ByteArray to dump, starting at 'position'
         * @param offset Override offset of ba
         * @param maxLength Amount of ByteArray to dump (default: all of it)
         * @return Formatted string containing hex values
        **/
        public static function DumpHex( ba:ByteArray, offset : uint = 0, maxLength : uint = uint.MAX_VALUE ) : String
        {
            const digits : String = "00000000";
            var abuff : String = "    00000000";
            var xbuff : String = "";
            var pbuff : String = "";
            var baposn : uint = ba.position;
            var result : String = "";
            ba.position = offset;
            var length : uint = Math.min(ba.bytesAvailable,maxLength);
            /* Format a line of dump */
            var curr : uint = 0;
            while( curr < length )
            {
                var b : uint = ba.readUnsignedByte();
                xbuff += " " + (b <= 0xf ? "0" + b.toString(16) : b.toString(16));
                pbuff += b < 32 || b > 127 ? '.' : String.fromCharCode(b);
                if( 0xf == (curr++ & 0xf) )
                {
                    result += abuff + ":" + xbuff + " | " + pbuff +"\n";
                    abuff = curr.toString(16);
                    abuff = "    " + digits.slice(0,8-abuff.length) + abuff;
                    xbuff = "";
                    pbuff = "";
                }
            }
            /* Leftovers */
            if( 0 != (length & 0xf) )
            {
                for( curr = (curr & 0xf); curr < 16; ++curr )
                {
                    xbuff += " --";
                    pbuff += ' ';
                }
                result += abuff + ":" + xbuff + " |" + pbuff +"\n";
            }
            ba.position = baposn;
            return result;
        }

        /**
         * Trace that Flex build eats
        **/
        public static function Trace( ...params ) : void
        {
            CONFIG::DEBUG { TraceMain.apply(null,params); }
        }

        /**
         * Add something to the log
         * @args Works just like trace, with variable arguments
         * @return Formatted string that was added to the log
        **/        
        public static function Log(...args) : void
        {
	        var level : int = LOG_INFO;
	        if( args[0] is int )
	            level = args.shift();
	        if( level > LOG_LEVEL )
	            return;

            var logMessage : String = DoubleTime.Get().toFixed(1) + ": ";
            var i : int;
            var obj : Object;
            for( i = 0; i < args.length; ++i )
            {
                obj = args[i];
                logMessage += null == obj ? "null" : obj.toString() + ' ';
            }
            CONFIG::DEBUG { trace(logMessage); }
            logMessage += "\n";
            logList.push(logMessage);
            if( logList.length > LOG_MAX )
            {   // By default, we don't save the log, or accumulate it forever
                logList.splice( 0, logList.length - LOG_MAX );
            }
            ed.dispatchEvent( new TextEvent(DEBUG_LOG,false,false,logMessage) );
        }

        /**
         * Add something to the log, also adds stack trace in trace output
         * @args Works just like trace, with variable arguments
         * @return Formatted string that was added to the log
        **/        
        public static function LogError(...args) : void
        {
            args.unshift(LOG_ERROR);
            Log.apply(null,args);
            TraceStack();
        }
        
        /**
         * Get a copy of the log's most recent events
         * @return A copy of the current log
        **/
        public static function GetLog() : Array
        {
            return logList.slice();
        }

        /**
         * Add something to the log
        **/
        public static function ClearLog() : void
        {
            logList = new Array();
            Log("Log Cleared");
        }

        /**
         * Listen for some debug notifications
        **/
        public static function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
        {
            ed.addEventListener(type, listener, useCapture, priority, useWeakReference );
        }

        /**
         * End some debug notifications
        **/
        public static function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
        {
            ed.removeEventListener(type, listener, useCapture );
        }

	    /**
	     * Trace the stack
	     * @param skip 'unimportant' portions of stack to skip (i.e. Assert function)
	     * @max Maximum depth to trace
	    **/
	    public static function TraceStack( skip:int=0, max:int=50 ) : void
	    {
	        // Filter out typical debug layers and overrides in call stack; get to the meat of it
            const rxMatch : RegExp = /(builtin::apply\(|LogError\(|TraceError\(|ThrowAssert\(|Assert\()/x;
	        var error : Error = new Error();
            var dump : String = error.getStackTrace();
            var errors : Array = dump.split('\n');
            errors = errors.slice(2+skip); // Error and top of stack (TraceStack), and any additional layers specified
            var bMatching : Boolean = true;
            while( null != (dump = errors.shift()) && max--)
            {
                if( bMatching && rxMatch.test(dump) )
                    continue;
                bMatching = false;
                trace(dump);
            }
        }
        /**
         * Trace current line of code
         * @param traceargs Passed to trace
        **/
        public static function TraceLine(...traceargs) : void
        {
CONFIG::DEBUG {
            if( 0 < traceargs.length )
                TraceMain.apply(NaN,traceargs);
            TraceStack(1,1); // Trace one line, skipping TraceLine
}
        }

        /** @private Maximum 'same' history befor emitting */
        private static const max_matches_hard : int = 100; 
        /** @private Maximum time collecting 'same' history, before reporting */
        private static const max_matches_time : int = 500;
        /** @private Trace history parameters */
        private static const history : Object = { lastoutput : "", nMatches : 0, timeout : -1 };
        public static function TraceMain(...traceargs) : void
        {
            var output : String = "";
            var arg : Object;
            while( 0 < traceargs.length )
            {
                arg = traceargs.shift();
                if( arg is Object )
                {
                    if( arg is Error )
                    {
                        var err : Error = arg as Error;
                        output += '\n'+err.toString();
                        output += '\n'+err.getStackTrace();
                    }
                    else if( arg is ByteArray )
                    {   // Dump byte array data with limits, and as tidy hex dump
                        var ba : ByteArray = arg as ByteArray;
                        const BA_MAX : uint = 1024;
                        output += "ByteArray " + ba.position + ", " + ba.length;
                        output += '\n'+DumpHex(ba,0,Math.min(ba.length,BA_MAX));
                    }
                    else if( arg is XML )
                    {
                        output += '\n'+((arg as XML).toXMLString())+'\n';
                    }
                    else if( arg is uint )
                    {
                        output += arg.toString()+' ';
                    }
                    else if( arg is int )
                    {
                        output += arg.toString()+' ';
                    }
                    else if( arg is Number )
                    {
                        output += Number(arg).toFixed(4)+' ';
                    }
                    else if( arg is Socket )
                    {
                        var sock : Socket = arg as Socket;
                        output += "Socket "+sock.remoteAddress+":"+sock.remotePort+" Connected:"+sock.connected;
                    }
                    else
                    {
                        output += arg.toString() + ' ';
                    }
                }
                else
                {
                    output += "null ";
                }
            }
            if( history.lastoutput == output )
            {
                ++history.nMatches;
                if( max_matches_hard <= history.nMatches )
                {   // If we're tracing in a hard loop, emit occasionally
                    TraceHistory();
                }
                else if( -1 == history.timeout )
                {   // Set a timeout to emit occasionally
                    history.timeout = setTimeout(TraceHistory,max_matches_time);
                }
                return;
            }
            function TraceHistory() : void
            {
                // Make trace logs less spammy
                if( 0 < history.nMatches )
                {
                    trace( history.lastoutput, 'x'+history.nMatches );
                }
                if( -1 != history.timeout )
                {
                    	clearTimeout(history.timeout);
                    	history.timeout = -1;
                }
                history.nMatches = 0;
            }
            TraceHistory();
            trace(output);
            history.lastoutput = output;
            output=null;
        }
        
        /**
         * Dump call stack on something, and debug details
         * @param traceargs Passed to trace
         * If various arguments are specific types, clean them up
        **/
        public static function TraceError( ...traceargs ) : void
        {
            traceargs.unshift("ERROR:");
            TraceMain.apply(NaN,traceargs);
            trace("Call stack...");
            TraceStack(1);
        }

        /**
         * Throw assertion without test
         * @param traceargs Passed to trace
        **/
	    public static function ThrowAssert( ...traceargs ) : void
	    {
CONFIG::DEBUG {
            traceargs.unshift("BREAKPOINT:");
            TraceError.apply(NaN,traceargs);
            enterDebugger();
}
	    }
        
        /**
         * Classic assertion
         * @param bSuccess Must pass or breakpoint happens
         * @param traceargs Passed to trace
        **/
	    public static function Assert( bSuccess : Boolean, ...traceargs ) : void
	    {
CONFIG::DEBUG {
	        if( !bSuccess )
            {
                traceargs.unshift("ASSERTION FAILURE:");
                TraceError.apply(NaN,traceargs);
                enterDebugger();
            }
}	        
	    }

    }
}
    
