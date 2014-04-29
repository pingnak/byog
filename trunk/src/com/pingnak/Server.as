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
     * This is the thing that listens for incoming connections, and makes and 
     * manages 'ClientConnection' objects. 
     *
    **/
    public class Server extends applet
    {
        /** Dispatched when it looks like server is bound and listening */
        public static const READY : String = "SERVER_READY";

        /** Dispatched when it looks like server is down */
        public static const CLOSE : String = "SERVER_SHUTDOWN";
        
        /** Dispatched when a client connects */
        public static const CONNECTED : String = "SERVER_CONNECTED"; 

        /** Dispatched when a client disconnects, or is disconnected */
        public static const DISCONNECTED : String = "SERVER_DISCONNECTED";

        /** Global instance to get */
        public static var instance : Server;
        
        /** Client configuration XML */
        public var xml : XML;

        /** Port to listen on */
        public var port : uint;
        
        /** Server socket to listen on */
        protected var serverSocket : ServerSocket;
        
        /** Database of banned naughty IP:PORTs */
        protected var banned : Dictionary;

        /** Database of banned naughty IP:PORTs */
        protected var resourcemap : Dictionary;
        
        /** IP this server can be found on */
        protected var my_ip : String = "0.0.0.0";

        /** Kinds of clients to build on connection */
        protected var clientClass : Class;

        /** Cache control for browser resources */
        internal  var cache_life : uint = 0;

        /** Client connections to manage the real work; dictionary can be iterated, but removing clients is trivial */
        internal  var clientConnections : Dictionary;
        
        /**
         * Server constructor
         * @param xml XML Configuration details
         * @param clientClass Kind of clients to make
        **/
        public function Server( xml:XML, clientClass : Class )
        {
            this.xml = xml;
            this.clientClass = clientClass;
            instance = this;
            cache_life = uint(xml.cache_life);
            banned = new Dictionary();
            clientConnections = new Dictionary();
        }
        
        /**
         * Bind to a port, and listen.
        **/
        public function Connect( ip:String, port:uint ) : Boolean
        {
            if( null != serverSocket && Address() != ip && Port() != port )
            {
                // Stop listening
                debug.Log("Server was already running.  Closing down.",Address()+":"+Port());
                Close();
            }
            
            debug.Log("Server Startup",ip+":"+port);

            this.port = port;
            this.my_ip = "0.0.0.0" == ip ? GetInterfaces()[0] : ip;


            var tmpss : ServerSocket = new ServerSocket(); 
            try
            {
                tmpss.bind( port, ip );
            }
            catch(e:Error)
            {
                debug.LogError(e);
                return false;
            }

            try
            {
                tmpss.listen();
            }
            catch(e:Error)
            {
                debug.LogError(e);
                return false;
            }
            
            if( tmpss.listening )
            {
                debug.Log("Listening:",Address()+":"+Port());
                serverSocket = tmpss;
                serverSocket.addEventListener( ServerSocketConnectEvent.CONNECT, onConnect );
                serverSocket.addEventListener( Event.CLOSE, Close );

                // Suck in the things the server can serve (not much)            
                resourcemap = new Dictionary();
                var i : int;
                var resources : XMLList = xml.resources.file;
                for( i = 0; i < resources.length(); ++i )
                {
                    var file : String = String(resources[i]).toLowerCase();
                    var dot : int = file.lastIndexOf(".");
                    var ext : String = -1 == dot ? "" : file.substring(dot).toLowerCase();
                    var ba : ByteArray = applet.LoadData(String(resources[i].@path)+file);
                    if( null != ba )
                    {
                        // Do some template substitutions on HTML/XML that we pass to client
                        // Convenient way to get details down there
                        if( ".html" == ext || ".xml" == ext )
                        {
                            var seded : String = ba.readUTFBytes(ba.length);
                            seded = XMLPack(file,seded); 
                            seded = seded.replace(/%PORT%/g, port.toString() );
                            
                            // Slurp up everything under Client_Parameters, and make it part of any html/xml that matches
                            // Parameters in target text is %boxed in%, with '%', to try to keep it separate.
                            var parameters : XMLList = xml.Client_Parameters.children();
                            var param : XML;
                            var regex : RegExp;
                            for each (param in parameters) 
                            {
                                regex = new RegExp("%"+param.name()+"%","g");
                                seded = seded.replace( regex, String(param) );
                            }
                            ba.length = ba.position = 0;
                            ba.writeUTFBytes(seded);
                        }
                        resourcemap[file] = ba;
                    }
                }
                dispatchEvent( new Event(READY) );
                return true;
            }
            
            tmpss.close();
            debug.LogError( "Server is DOA.  Try a different port or kill a zombie process." );
            return false;
        }

        public function Running() : Boolean { return null != serverSocket && serverSocket.listening; }
        public function Address() : String { return my_ip; }
        public function Port() : int { return port; }

        /**
         * Get a list of available IP addresses
        **/
        public static function GetInterfaces(ipV6 : Boolean = false) : Array
        {
            var networkInfo : NetworkInfo = NetworkInfo.networkInfo;
            var interfaces : Vector.<NetworkInterface> = networkInfo.findInterfaces();
            var interfaceObj : NetworkInterface;
            var address : InterfaceAddress;
            var result : Array = [];
            var i : int;
            var j : int;
            //Get available interfaces
            for ( i; i < interfaces.length; i++)
            {
                interfaceObj = interfaces[i];
            
                for ( j = 0; j < interfaceObj.addresses.length; j++ )
                {
                    address = interfaceObj.addresses[j];
                    // Exculde loopback, and ipV6 addresses, unless asked for
                    if( address.address != "127.0.0.1" && 
                        ((ipV6 && address.address != "::1") || -1 == address.address.indexOf(":")) )
                        result.push(address.address);
                }
            }
            return result;
        }
        
        /**
         * Incoming TCP 
        **/
        protected function onConnect( event:ServerSocketConnectEvent ) : void
        {
            var socket : Socket = event.socket;
            
            // Make sure incoming connection isn't 'banned'
            debug.Log("Server received connection from "+socket.remoteAddress+":"+socket.remotePort);
            
            // Incoming connections are initially assumed to be a web client
            clientConnections[socket] = new clientClass(this,socket);
            
            dispatchEvent( new Event(CONNECTED) );
            
        }

        /**
         * Allow client connections to clean themselves out of database
        **/
        internal function onDisconnect( clientConnection : ClientConnection  ) : void
        {
            // Clean up after 
            //debug.Log( "Disconnect",clientConnection.socket.remoteAddress+":"+clientConnection.socket.remotePort );
            delete clientConnections[clientConnection.socket];
            dispatchEvent( new Event(DISCONNECTED) );
        }
        
        /**
         * Add a naughty address to blacklist
        **/
        public function Ban(ip:String, port:uint, reason:String = "Just Because" ) : void
        {
            var id : String = ip+":"+port.toString();
            banned[id] = debug.Log( id + "Banned", reason + ": " );
        }

        /**
         * Remove a naughty address from blacklist
        **/
        public function Allow(ip:String, port:uint, reason:String = "Just Because" ) : void
        {
            var id : String = ip+":"+port.toString();
            delete banned[id];
            debug.Log( id + "Allowed", reason + ": " );
        }

        /**
         * Invoke function on each client
         * @param fun Callback(ClientConnection):void
        **/
        public function ForEachClient( fun : Function ) : void
        {
            var cc : ClientConnection;
            for each( cc in clientConnections )
            {
                fun(cc);
            }
        }

        /**
         * Invoke function on each client; STOP on first that returns true
         * @param function Callback(ClientConnection):Boolean
         * @return ClientConnection that returned true, or null
        **/
        public function ForEachClientUntil( fun : Function ) : ClientConnection
        {
            var cc : ClientConnection;
            for each( cc in clientConnections )
            {
                if( fun(cc) )
                    return cc;
            }
            return null;
        }
        
        /**
         * Shut down server
        **/
        public function Close(e:Event=null) : void
        {
            // Make sure we have no clients left
            var cc : ClientConnection;
            var todo : Array = new Array();
            for each( cc in clientConnections )
            {
                todo.push(cc);
            }
            if( 0 != todo.length )
            {
                while( 0 < todo.length )
                {
                    cc = todo.shift();
                    if( null != cc.socket )
                    {
                        delete clientConnections[cc.socket];
                    }
                    cc.Close();
                }
                clientConnections = new Dictionary();
            }
            if( null != serverSocket )
            {
                if( null != e && e.type == Event.CLOSE )
                {   // If we got 'close' event, close
                    dispatchEvent( new Event(CLOSE) );
                }
                debug.Log( debug.LOG_IMPORTANT, "Shutting down" );
                var ss : ServerSocket = serverSocket;
                serverSocket = null;
                ss.close();
            }
            else
            {
                //debug.LogError( "Server already shut down." );
            }
        }

        /**
         * Key codes
        **/
        public function Key( str : String ) : void
        {
        }

        /**
         * 'Mouse click' 
        **/
        public function Click( x:Number, y:Number ) : void
        {
        }

        public function ClickOn( dobj : DisplayObject, x:Number, y:Number ) : void
        {
        }

        /**
         * Get a resource from our pool
        **/
        public function GetResource(id:String):ByteArray
        {
            return resourcemap[id] as ByteArray;
        }

        /**
         * Clean up extra white space and comments from the xml/html that we serve
         * @param readable The original xml text
         * @return Something 'identical', but with less white space, and no comments
        **/
        protected static function XMLPack( file : String, readable : String ) : String
        {
            var iteration : String = readable;
            
            // Dropping 'log', 'trace' and 'assert' into your code will emit appropriate js for debug/release builds
            // Walking through the regex:
            //     From the beginning of the line, all tabs and spaces, to the word, in a group to be put back in replacement
            //     Optional whitespace to the opening paren, all in group, matching to ');'
            //     Ignore capitalization/case (trace/TRACE/Trace), all of them
            const rxLog    : RegExp = new RegExp("\([^A-Za-z0-9_.]\)log\((.*?)\);","igx");
            const rxTrace  : RegExp = new RegExp("\([^A-Za-z0-9_.]\)trace\((.*?)\);","igx");
            const rxAssert : RegExp = new RegExp("\([^A-Za-z0-9_.]\)assert\((.*?)\);","igx");
            
            // Wrap console.log in error trap, mainly because of rude browsers that don't provide 'console', unless debugger is up 
            iteration = iteration.replace(rxLog,   '$1{ try {console.log($2);} catch(e){} }');
            
CONFIG::DEBUG {
            // Turn on proper debug instrumentation
            iteration = iteration.replace(rxTrace,   "$1{ try {console.log($2);} catch(e){} }");

            // Assert will quietly fail, without the debugger present 
            iteration = iteration.replace(rxAssert,  "$1{ if( !($2) ) { try { console.log('Assertion Failed: $2' ); console.log((new Error()).stack); debugger; } catch(e) {} } }");
}
            
CONFIG::RELEASE {            
            // Remove debug instrumentation 
            iteration = iteration.replace(rxTrace, '$1/* trace($2); */');
            iteration = iteration.replace(rxAssert,'$1/* assert($2); */');
}

CONFIG::RELEASE {            
            var istart : int;
            var icurr : int;
            var iend : int;

            // Run through a string, eating 'comments'
            function EatBlocks(main:String, startBlock:String, endBlock:String ):String
            {
                var istart : int;
                var iend : int;
                var current : String = main;
                while( -1 < (istart = current.indexOf(startBlock)) )
                {
                    iend = current.indexOf(endBlock,istart+startBlock.length);
                    if( -1 == iend )
                    {
                        debug.LogError( "Unterminated "+startBlock );
                        return main;
                    }
                    current = current.substring(0,istart) + current.substring(iend+endBlock.length);
                }
                return current;
            }

            // Debug mode: 
            // Surround debug-only script with <!--DEBUG--><!--/DEBUG-->, to make sure it's eaten by this
            // Add an unbounded <!--DEBUG--> to disable in 'release' mode.  You'll get an error warning
            // but all the debug code will be left intact
            iteration = EatBlocks( iteration, "<!--DEBUG-->", "<!--/DEBUG-->" );
            
            // Eat the XML comments.
            iteration = EatBlocks( iteration, "<!--", "-->" );

            // Eat the C-like comments.
            iteration = EatBlocks( iteration, "/*", "*/" );

            // Remove '//' comments, except in lines with quotes before
            // Regex was acting all kinds of buggy
            var lines : Array = iteration.split("\n");
            var lineCurr : String;
            var foundQuote : int;
            for( icurr = 0; icurr < lines.length; ++icurr )
            {
                lineCurr = lines[icurr];
                foundQuote = lineCurr.indexOf("'");
                if( -1 == foundQuote )
                    foundQuote = lineCurr.indexOf('"');
                istart = lineCurr.indexOf("//");
                if( -1 != istart )
                {
                    if( -1 == foundQuote || foundQuote>istart )
                        lineCurr = lineCurr.substring(0,istart);
                }
                lines[icurr] = lineCurr;
            }
            iteration = "";
            var iLine : int = 0;
            while( 0 < lines.length )
            {
                ++iLine;
                lineCurr = lines.shift();
                // Gnaw white spaces off start and ends of lines
                const rxEatSpaces : RegExp = /^[\s]+/gim;
                const rxEatSpaces2 : RegExp = /[\s]+$/gim;
                lineCurr = lineCurr.replace(rxEatSpaces,'');
                lineCurr = lineCurr.replace(rxEatSpaces2,'');
                
                // Non-blank, lines should end with ';' or ','
                const rxKeysParen : RegExp = /^(if|else.if|for|while|switch|catch|finally)[\s]*\(/;
                const rxKeysColon : RegExp = /^(case|default)/;
                const rxKeysAlone : RegExp = /^(do|else|try)$/;
                const rxFunction  : RegExp = /function/;
                
                if( '' != lineCurr )
                {
                    switch( lineCurr.charAt(lineCurr.length-1) )
                    {
                    case ')':
                        if( !rxKeysParen.test(lineCurr) && !rxFunction.test(lineCurr) )
                            debug.LogError(file,"Likely missing semicolon.\n"+lineCurr );
                        iteration += lineCurr;
                        break;
                    case ':':
                        if( !rxKeysColon.test(lineCurr) )
                            debug.LogError(file,"Possible colon where semicolon belongs?\n"+lineCurr );
                        iteration += lineCurr;
                        break;
                    case ',':
                    case ';':
                    case '{':
                    case '}':
                    case '>':
                        iteration += lineCurr;
                        break;
                    default:
                        if( rxKeysAlone.test(lineCurr) )
                        {
                            iteration += lineCurr+' ';
                        }
                        else
                        {
                            iteration += lineCurr+"\n";
                        }
                        break;
                    }
                }
            }
            
            // Spaces around operators, parens, braces
            const regexOperatorSpace : RegExp = new RegExp("([/\>\<\!\=\+\-\*\&\|\(\)\{\}]+)[ \t]+","g");
            iteration = iteration.replace(regexOperatorSpace,'$1');
            const regexSpaceOperator : RegExp = new RegExp("[ \t]+([/\>\<\!\=\+\-\*\&\|\(\)\{\}]+)","g");
            iteration = iteration.replace(regexSpaceOperator,'$1');

            // Turn all runs of spaces into space
            const regexSpace : RegExp = /[ \t]+/g;
            iteration = iteration.replace(regexSpace,' ');
}// CONFIG::RELEASE            
            return iteration;
        }

    }
}
