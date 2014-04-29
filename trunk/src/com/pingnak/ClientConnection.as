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
     * Base class for various kinds of 'servers' on this connection.
     *
     * Handle all the underlying errors and house keeping
     *
     * Web browsers are kind of nasty.  They want to make multiple connections
     * and leave them all open.  Which is 'fine', for a given value of fine.
     *
     * However, this presents us with a problem.  Over the internet, all of 
     * these sockets are potentially anonymous.  IP:PORT may be meaningless
     * for identifying a particular 
     *
    **/
    public class ClientConnection extends EventDispatcher
    {
        /** Don't parse ANY messages to server that are bigger than this. Disconnect with error. */
        internal static const MAX_GIVEUP : uint = 1024;
        
        /** How long to wait for error message to go out, before closing */
        internal static const SOCKET_CLOSE_GIVEUP : uint = 1000;
        
        /** How long to wait for error message to go out, before closing */
        internal static const INACTIVITY : uint = 15000;

        internal static const CLIENT_HTML : String = "client.html";

        /** 
         * Timer for inactivity cleanup
         * Browsers open a whole BUNCH of sockets, and then don't use them.
        **/
        private var DoomsDay : Timer;
        private var MS_REASONABLE_INVISIBILITY : uint = 10000;
        

        /*
         * Server/Housekeeping Properties
         */
        
        /** Which server this is from */
        internal var server : Server;

        /** What to call this in log messages */
        public var friendly_name : String;
        public var browser : String = "";
        public var OS : String = "";
        public var user_agent_full : String = "";
        public var user_agent_short : String = "";

        /** Are we in web socket mode? */
        public var bWsMode : Boolean = false;
        
        /** Socket data */
        public var socket : Socket;
        
        /** Peek buffer; decode just enough to 'see' what we're looking for */
        internal var message : ByteArray;
        
        /** Set when we want to wait for output to complete, before closing */
        protected var bPendingClose : Boolean = false;
        
        /** How many bytes remain to be sent */
        private var _bytesPending : uint = 0;
        
        /** How many bytes have been sent */
        private var _bytesTotal : uint = 0;

        /** How long we leave socket open, waiting for output */
        internal var ClosingGrace : Timer;

        public final function get ready():Boolean { return null != socket && socket.connected; }
        
        /** Get how many bytes are waiting to be sent */
        public final function get bytesPending():uint {return _bytesTotal;}
        
        /** Get how many bytes have been sent */
        public final function get bytesTotal():uint {return _bytesTotal;};
        
        internal var prevHeader : String = "";

        /** A sessionid to identify a 'real' session. */
        public var SESSION : String = "";

        protected var baPool : ByteArrayPool;
        
        public function ClientConnection( server:Server, socket:Socket )
        {
            this.server = server;
            this.socket = socket;
            socket.endian = Endian.BIG_ENDIAN;

            // What we build incoming messages from
            message = new ByteArray();
            
            // A pool of work memory
            baPool = new ByteArrayPool(3,false,false);

            server.clientConnections[socket] = this;            
            friendly_name = socket.remoteAddress+":"+socket.remotePort+" Unknown";
            socket.addEventListener( Event.CLOSE, Close );
            socket.addEventListener( IOErrorEvent.IO_ERROR, TraceError );
            socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, TraceError );
            socket.addEventListener( OutputProgressEvent.OUTPUT_PROGRESS, OutputProgress );
            
            MS_REASONABLE_INVISIBILITY = uint(server.xml.Client_Parameters.MS_REASONABLE_INVISIBILITY);
            if( 1000 > MS_REASONABLE_INVISIBILITY )
                MS_REASONABLE_INVISIBILITY = 10000;
            DoomsDay = new Timer(MS_REASONABLE_INVISIBILITY, 1);
            DoomsDay.addEventListener( TimerEvent.TIMER_COMPLETE, DoomsDayHandler );
            // Start timer NOW.  Don't just leave anonymous sockets dangling, forever
            DoomsDayPostpone();

            // Start in 'Web Mode', since this is nominally an HTTP server
            SetWebMode();
        }

        /**
         * Keep track of output progress.
         * Since AIR3, there has been a Socket.bytesTotal, Socket.bytesPending 
         * properties; however, I'd like to make sure this builds for older AIR,  
         * because of Linux and Adobe's short-sightedness.
        **/
        private final function OutputProgress(e:OutputProgressEvent):void
        {
            socket.flush();
            _bytesTotal = e.bytesTotal;
            _bytesPending = e.bytesPending;
            if( bPendingClose )
            {
                Log(_bytesPending);
                if( 0 == _bytesPending )
                {
                    Log("Finished Sending.");
                    Close();
                }
            }
        }

        // Dummy function to make calling 'unimplemented' function calls harmless
        public static function Ignore(...rest):void {}

        /**
         * Set new mode for send/receive
         * We start with a Web mode, but switch to either a WebSocket or 'long poll' mode, afterwards, according to what the client has
         * @param received (e:ProgressEvent):void
         * @param sendtext (string:String):void;
         * @param sendbytes (ba:ByteArray,length:uint=uint.MAX_VALUE):void;
         * @param sent (e:OutputProgressEvent):void
        **/
        public function SetMode( received:Function = null, sent:Function = null ) : void
        {
            if( null == socket )
            {
                this.Sent = Ignore;
                this.Received = Ignore;
                TraceError( "Bad Socket" );
                return;
            }
            socket.removeEventListener( OutputProgressEvent.OUTPUT_PROGRESS, Sent );
            socket.removeEventListener( ProgressEvent.SOCKET_DATA, Received );
            if( null != received )
            {
                this.Received = received;
                socket.addEventListener( ProgressEvent.SOCKET_DATA, Received );
            }
            else
            {
                this.Received = Ignore;
            }
            if( null != sent )
            {
                this.Sent = sent;
                socket.addEventListener( OutputProgressEvent.OUTPUT_PROGRESS, Sent );
            }
            else
            {
                this.Sent = Ignore;
            }
        }
        
        /**
         * Set initial http 1.1 web server mode.
         * We remain in this mode for 'long poll' mode, if client does not support WebSockets 
         * Older phones/tablets that can't be upgraded will continue to exist... for years
         * http://www.w3.org/Protocols/
         * https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol
        **/
        public function SetWebMode() : void
        {
            bWsMode = false;
            friendly_name = "http://"+socket.remoteAddress+":"+socket.remotePort+" "+user_agent_short;
            //Log("SetWebMode");
            SetMode( HTTPReceived );
        }

        /**
         * Set to WebSocket mode to carry on somewhat simplified protocol, compared to http 
         * https://tools.ietf.org/html/rfc6455
         * https://en.wikipedia.org/wiki/WebSocket
        **/
        public function SetWebSocketMode() : void
        {
            bWsMode = true;
            friendly_name = "ws://"+socket.remoteAddress+":"+socket.remotePort+" "+user_agent_short;
            //Log("SetWebSocketMode");
            SetMode( WSReceived );
        }

        /**
         * Received data parser
        **/
        public var Received : Function = Ignore;//(e:ProgressEvent):void;

        /**
         * Sent data (make sure queue is nearly empty before sending more video updates)
        **/
        public var Sent : Function = Ignore;//(e:OutputProgressEvent):void;
        
        /**
         * Tack on client log information
        **/
        public function Log(...args) : void
        {
            args.unshift(friendly_name+":");
            debug.Log.apply(null,args);
        }

        /**
         * Tack on client log information
        **/
        public function LogError(...args) : void
        {
            args.unshift(friendly_name+":");
            debug.LogError.apply(null,args);
        }
        
        /**
         * Tack on client Trace information
        **/
        public function Trace(...args) : void
        {
CONFIG::DEBUG {
            args.unshift(friendly_name+":");
            debug.Trace.apply(null,args);
}
        }
        
        /**
         * Tack on client information for TraceError
        **/
        public function TraceError(...args) : void
        {
            args.unshift(friendly_name);
            debug.TraceError.apply(null,args);
        }

        
        /**
         * Reset watchdog timer 
        **/
        public function DoomsDayPostpone() : void
        {
            if( null != DoomsDay )
            {
                DoomsDay.reset();
                DoomsDay.start();
            }
        }

        /**
         * Stop watchdog timer 
        **/
        public function DoomsDayCancel() : void
        {
            if( null != DoomsDay )
            {
                DoomsDay.reset();
                DoomsDay.removeEventListener( TimerEvent.TIMER_COMPLETE, DoomsDayHandler );
                DoomsDay = null;
            }
        }
        
        /**
         * Watchdog to clean up dangling connections
        **/
        protected function DoomsDayHandler(e:Event) : void
        {
            DoomsDayCancel();
            if( bWsMode )
            {
                WSSendError("Inactivity.");
            }
            else
            {
                HTTPSendBorked( "408 Connection timed out" );
            }
        }
        
        /**
         * Socket has closed down (or needs to), for whatever reason
        **/
        public function Close( e:Event = null ) : void
        {
            Trace("ClientConnection.Close");
            ClientBundle.RemoveClient(this);
            
            DoomsDayCancel();
            
            if( null != ClosingGrace ) 
            {
                ClosingGrace.stop();
                ClosingGrace.removeEventListener( TimerEvent.TIMER_COMPLETE, Close );
            }

            // For debug, I'd like to see where the close events came from
            //applet.TraceStack(1);
            if( null != socket )
            {
                socket.removeEventListener( OutputProgressEvent.OUTPUT_PROGRESS, OutputProgress  );
                socket.removeEventListener( IOErrorEvent.IO_ERROR, TraceError );
                socket.removeEventListener( SecurityErrorEvent.SECURITY_ERROR, TraceError );
                socket.removeEventListener( Event.CLOSE, Close );
                SetMode();
                server.onDisconnect(this);
                server = null;
                if( socket.connected )
                    socket.close();
                socket = null;
            }
            if( null != baPool )
            {
                baPool.Flush();
                baPool = null;
            }

        }
 
        /**
         * Finish sending, then close
        **/
        internal function CloseWhenFinished() : void
        {
            Trace( "Waiting to send..." );
            // Stop receiving data
            if( null != ClosingGrace )
                return;
                
            ClosingGrace = new Timer(SOCKET_CLOSE_GIVEUP,1);
            ClosingGrace.addEventListener( TimerEvent.TIMER_COMPLETE, Close );
            ClosingGrace.reset();
            ClosingGrace.start();

            socket.flush();
            socket.removeEventListener( ProgressEvent.SOCKET_DATA, Received );
            socket.addEventListener( OutputProgressEvent.OUTPUT_PROGRESS, OutputProgress  );
            bPendingClose = true;
        }
        
        /**
         * Watch incoming data, to build message
        **/
        internal function HTTPReceived(e:ProgressEvent) : void
        {
            /** Append data onto message parser */
            socket.readBytes(message, message.length, socket.bytesAvailable );
            //Trace("HTTPReceived",message.length,"bytes");

            message.position = 0;
            var decode : String = message.readUTFBytes(message.length);

            if( message.length > MAX_GIVEUP )
            {   // Don't handle 'infinite' messages.
                HTTPSendBorked( "413 Request Entity Too Large" );
            }
            
            // Look for last blank line of header
            var headerLen : int = decode.indexOf("\r\n\r\n")+4;
            var contentLen : int;
            
            if( -1 != headerLen )
            {   // Got a header
                var header : String = decode.substring(0,headerLen);
                if( "" == user_agent_short )
                {
                    // Attempt to improve our diagnostic logs from User-Agent text
                    friendly_name = GetBrowserDetails(header);
                    friendly_name = "http://"+socket.remoteAddress+":"+socket.remotePort+" "+user_agent_short;
                    //debug.Log(friendly_name+'\n'+user_agent_full);
                }

                const match_length : RegExp = /content-length:/i;
                contentLen = header.search(match_length);
                if( -1 != contentLen )
                {
                    // If there is extra crap on a message, get that, too.
                    // There shouldn't be.
                    contentLen = int(decode.substr(contentLen+16,decode.indexOf("\r\n",contentLen+16)));
                    if( contentLen < 0 )
                    {   // Content must be a positive integer
                        HTTPSendBorked( "413 Request Entity Too Large" );
                        return;
                    }
                    if( contentLen + headerLen > MAX_GIVEUP )
                    {   // Prevent bogons with super-huge content
                        HTTPSendBorked( "413 Request Entity Too Large" );
                        return;
                    }
                }
                else
                {
                    contentLen = 0;
                }
                message.position = headerLen;
                prevHeader = header;

                HTTPReceivedMessage(header, message, contentLen);
                
                message.position = headerLen + contentLen;
                
                // First thing, pop the header off the message parser
                if( message.position < message.length )
                {   // Read message to its self, to shift un-parsed data to beginning
                    message.readBytes(message,0,message.length-message.position);
                    message.length -= message.position;
                    message.position = 0;
                }
                else
                {   // Clear message buffer
                    message.position = 0;
                    message.length = 0;
                }
            }
        }

        /**
         * Send an error response, then close down connection when fully sent.
         * @param how An error code and brief error message
         * @param more Optional additional content
        **/
        public function HTTPSendBorked( how : String = "400 BAD REQUEST", more:ByteArray = null ) : void
        {
            Trace("HTTPSendBorked:",how);
            DoomsDayCancel();
			if( null == socket || bPendingClose )
			{
			    TraceError( "Bad Socket" );
			    return;
			}
            var main : String = "HTTP/1.1 "+how+"\r\nDate: "+utils.RFC822_Time()+"\r\nConnection: close\r\n";
            if( null != more )
            {
                main += "Content-Length: "+ more.length +"\r\n\r\n";
                socket.writeUTFBytes(main);
                socket.writeBytes(more);
                socket.flush();
            }
            else
            {
                socket.writeUTFBytes(main+"\r\n");
                socket.flush();
            }
            CloseWhenFinished();
        }

        /**
         * Make top half of 'OK' header
         * You can add stuff, but you MUST end with blank line (extra "\r\n")
         * @return Invariant header content
        **/
        public static function Make200Header(bCache:Boolean = false):String
        {
            // We have to return ALL KINDS OF 'do not cache'
            var ret : String = "HTTP/1.1 200 OK\r\nDate: "+utils.RFC822_Time();
            if( bCache )
                ret += "\r\nServer:BYOG\r\nCache-Control: public, max-age="+Server.instance.cache_life+"\r\n";
            else
                ret += "\r\nServer:BYOG\r\nCache-Control: no-cache, no-store, must-revalidate\r\nPragma: no-cache\r\nExpires: 0\r\n";
            return ret;
        }
        
        /**
         * Send response data back to HTTP client
         * @param bCache Whether the client should cache this data
         * @param ba Data to return
         * @param position Optional start position in ba to send from
         * @param length Optional length within ba to send
        **/
        public function HTTPRespond( ba : ByteArray, bCache:Boolean = false, position : uint = 0, length : uint = uint.MAX_VALUE ) : void
        {
            position = Math.min(ba.length,position);
            length = Math.min(ba.length-position,length);
            var response : String = Make200Header() + "Content-Length: " + length +"\r\n\r\n";
            socket.writeUTFBytes(response);
            socket.writeBytes( ba, position, length );
            socket.flush();
        }
        
        /**
         * We've fully received incoming data in 'Message'.
         *
         * Do something with it.
         *
         * @param header The http header, all lower case
         * @param ba ByteArray with 'position' at start of message, length bytes long
         * @param length Length of ba to use
        **/
        protected function HTTPReceivedMessage( header : String, ba:ByteArray, length : int = 0 ) : void
        {
            //Trace("HTTPReceivedMessage\n"+header+"----");
            //Trace(debug.DumpHex( ba, ba.offset, length ));
            DoomsDayPostpone();

            // Cut header up into lines
            var aHeads : Array = header.split("\r\n");
            const rxEatSpaces : RegExp = /[\s\r\n]*/gim;

            // Cut first line up into its elements
            var cmdLine : Array = aHeads[0].split(" ");
            var cmd : String = cmdLine[0];
            var address : String = cmdLine[1];

            var response : String;
            var found : ByteArray;
            var ikey : int;
            var ikeyend : int;
            var keyIn : String;

            var CMD : String = cmd.toUpperCase();

            // Handle returning a resource
            if( CMD == "GET" || CMD == "HEAD" )
            {
                var resourceID: String = CLIENT_HTML;
                var islash : int = address.lastIndexOf('/');
                if( -1 != islash )
                {
                    var iques  : int = address.indexOf('?',islash+1);
                    if( -1 != iques )
                    {
                        resourceID = address.slice(islash+1,iques);
                    }
                    else
                    {
                        resourceID = address.slice(islash+1);
                    }
                    if( "" == resourceID )
                    {
                        resourceID = CLIENT_HTML;
                    }
                    else
                    {
                        resourceID = resourceID.toLowerCase();
                    }
                }
            }
            
            switch( CMD )
            {
            case "HEAD":
                response = Make200Header(true);
                response += "\r\n";
                socket.writeUTFBytes(response);
                socket.flush();
                break;

            case "GET":
            
                /**
                 * Lock out 'get' flooding for main page, which could spawn multiple sessions
                 * Noticed when Android 4.04 generated empty GET requests for every XMLHttpRequest on long poll
                **/
                if( CLIENT_HTML == resourceID )
                {
                    if( !ClientBundle.AllowNewSession(this) )
                    {
                        HTTPSendBorked( "404", server.GetResource("404multi.html") );
                        return;
                    }
                    ClientBundle.New( this, friendly_name );
                }
                else
                {
                    ClientBundle.GetSession( this, address );
                }

                // Handle the switch to WebSocket
                const Close_Match : RegExp = new RegExp("\nConnection: close","i");
                const WebSocket_Key_Sig : String = "\nsec-websocket-key:";
                const WebSocket_Match : RegExp = new RegExp(WebSocket_Key_Sig,"i");
                ikey = header.search(WebSocket_Match);
                if( -1 != ikey )
                {
                    const WebSocket_UUID : String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
                    const WebSocket_Response : String = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept:";
                    ikey += WebSocket_Key_Sig.length;
                    ikeyend = header.indexOf("\r\n",ikey);
                    keyIn = header.substring(ikey,ikeyend);
                    keyIn = keyIn.replace(rxEatSpaces,"");
                    response = keyIn+WebSocket_UUID;
                    var baResponse : ByteArray = SHA1.FromString(response);
                    response = utils.BytesToBase64( baResponse );
                    var result : String = WebSocket_Response+response+"\r\n\r\n";
                    socket.writeUTFBytes(result);
                    socket.flush();
                    SetWebSocketMode();
CONFIG::DEBUG {
                    Trace( "WS Connection:", address );
                    Trace( resourceID );
                    debug.Assert( "" != SESSION ); 
}
                    return;
                }

                found = server.GetResource(resourceID); 
                
                // See if the app wants to hook it before we 'not found' it.
                if( null == found )
                {
                    if( ClientBundle.Handle_HTTPAppMessage( this, address, header, ba, length  ) )
                    {
                        // Handled; no need to error out
                        return;
                    }
                    HTTPSendBorked( "404 NOT FOUND: "+resourceID, server.GetResource("404.html") );
                    return;
                }

CONFIG::DIKEIN {
                /**
                 * Some browsers want to 'stream' my audio... for some reason.
                 * iOS chokes on audio, unless the range stuff is done for it.
                 * iOS and Android don't seem to cache, that.  
                 * Use WebKit Audio, if available.
                **/
                const Range_Key_Sig : String = "\nRange:";
                const Range_Match : RegExp = new RegExp(Range_Key_Sig,"i");
                ikey = header.search(Range_Match);
                if( -1 != ikey )
                {
                    ikey += Range_Key_Sig.length;
                    ikeyend = header.indexOf("\r\n",ikey);
                    keyIn = header.substring(ikey,ikeyend);
                    keyIn = keyIn.replace(rxEatSpaces,"");
                    if( '' == keyIn )
                    {
                        response = Make200Header() + "\r\nTransfer-Encoding:\r\nContent-Length: "+found.length+"\r\nAccept-Ranges: bytes\r\n\r\n";
                        socket.writeUTFBytes(response);
                        socket.flush();
                        return;
                    }
                    
                    // We are sending a subset...
                    var begin : uint = 0;
                    var end   : uint = found.length-1;
                    var total : uint = found.length;

                    // We only accept bytes
                    var aParse : Array = keyIn.split('=');
                    if( "bytes" != aParse[0].toLowerCase() )
                    {
                        HTTPSendBorked( "416 Requested Range Not Satisfiable "+ keyIn);
                        return;
                    }
                    // Parse range
                    aParse = keyIn.split('-');
                    begin = uint(aParse[0]);
                    if( 2 == aParse.length )
                    {   // iOS sends bad requests.  We will send a 'minimum' size back
                        end = uint(aParse[1]);
                        if( 0 == end )
                        {
                            end = found.length-1;
                        }
                    }
                    end = Math.min(end,total-1);
                    total = 1+end-begin;
                    if( total == found.length )
                        response = "HTTP/1.1 200 OK";
                    else
                        response = "HTTP/1.1 206 Partial Content";
                    response += "\r\nDate: "+utils.RFC822_Time()+"\r\nCache-Control: public, max-age="+server.cache_life+
                        "\r\nTransfer-Encoding:\r\nAccept-Ranges: bytes\r\n";
                    response += "Content-Range: bytes "+begin+"-"+end+"/"+found.length;
                    response += "\r\nContent-Length: "+total;
                    response += "\r\n\r\n"
                    socket.writeUTFBytes(response);
                    socket.writeBytes(found,begin,1+end-begin);
                    socket.flush();
                    //Trace("RETURNED RANGE:");
                    //Trace(response);
                    if( -1 != header.search(Close_Match) )
                    {
                        CloseWhenFinished();
                    }
                    return;
                }
} //CONFIG::DIKEIN
                var dot : int = resourceID.lastIndexOf(".");
                var ext : String = -1 == dot ? "" : resourceID.substring(dot).toLowerCase();
                if( ".html" == ext || ".xml" == ext )
                {
                    // Fill in some info for this client
                    found.position = 0;
                    var seded : String = found.readUTFBytes(found.length);
                    seded = seded.replace(/%FPS%/g, server.stage.frameRate.toString() );
                    seded = seded.replace(/%IP%/g, socket.localAddress+":"+server.port );
                    seded = seded.replace(/%SESSION%/g, SESSION );

                    response = Make200Header();
                    response += "Content-Length: " + seded.length +"\r\n\r\n";
                    socket.writeUTFBytes(response);
                    socket.writeUTFBytes(seded);
                    socket.flush();
                }
                else
                {
                    // Cache non XML/HTML things
                    response = Make200Header(true);
                    response += "Content-Length: " + found.length +"\r\n\r\n";
                    socket.writeUTFBytes(response);
                    socket.writeBytes(found,0,found.length);
                    socket.flush();
                }
                if( -1 != header.search(Close_Match) )
                {
                    CloseWhenFinished();
                }
                break;
            case "OPTIONS":
                response = Make200Header()+"Allow: OPTIONS, GET, HEAD\r\n\r\n";
                socket.writeUTFBytes(response);
                socket.flush();
                break;
            default:
                HTTPSendBorked( "501 NOT IMPLEMENTED" );
                break;
            }
        }
        
        /**
         * Watch incoming data, to build message
        **/
        internal function WSReceived(e:ProgressEvent) : void
        {
            socket.readBytes(message, message.length, socket.bytesAvailable );
            //message.position = 0;    
            //Trace("DUMP\n"+debug.DumpHex(message));
            if( message.length >= 2 )
            {
                var sign : uint = message.readUnsignedByte();
                var opcode : uint = sign & 0x0f;
                var mask_value : uint = 0;
                if( (sign & 0xf0) != 0x80 )
                {
                    Log( "Bad packet signature 0x" + sign.toString(16), "expect final messages with no extensions." );
                    // Close it.
                    Close();
                    return;
                }
                var len  : uint = message.readUnsignedByte();
                var mask : Boolean = 0 != (len & 0x80);
                var needlen : uint = mask ? 6 : 2; // 2 byte header + mask size
                len &= 0x7f;
                if( len <= 125 )
                {
                    if( message.length < needlen )
                        return;
                }
                else if( len == 126 )
                {
                    needlen += 2;
                    if( message.length < needlen )
                        return;
                    len = message.readUnsignedShort();
                }
                else //if( len == 127 )
                {
                    needlen += 8;
                    if( message.length < needlen )
                        return;
                    len = message.readUnsignedInt();
                    // We throw away the top 32 bits of the ridiculously big 64 bit length
                    len = message.readUnsignedInt();
                }
                if( MAX_GIVEUP < needlen )
                {
                    WSSendError("EXCESSIVE",1009);
                    return;
                }
                if( message.length < needlen )
                {   // Not enough to parse message
                    return;
                }
                if( mask )
                {
                    mask_value = message.readUnsignedInt();
                }

                DoomsDayPostpone();
                switch( opcode )
                {
                case 1:     // TEXT
                case 2:     // BINARY
                case 9:     // PING
                    var baReceived : ByteArray;
                    if( 0 != mask_value )
                    {
                        baReceived = baPool.New();
                        baReceived.length = len;
                        var remain : uint = len;
                        while( remain >= 4 )
                        {
                            baReceived.writeUnsignedInt( mask_value ^ message.readUnsignedInt() );
                            remain -= 4;
                        }
                        switch( remain )
                        {
                        case 3:
                            baReceived.writeByte( ((mask_value>>24)&0xff) ^ message.readUnsignedByte() );
                            baReceived.writeByte( ((mask_value>>16)&0xff) ^ message.readUnsignedByte() );
                            baReceived.writeByte( ((mask_value>>8 )&0xff) ^ message.readUnsignedByte() );
                            break;
                        case 2:
                            baReceived.writeShort( (mask_value>>>16) ^ message.readUnsignedShort() );
                            break;
                        case 1:
                            baReceived.writeByte( ((mask_value>>24)&0xff) ^ message.readUnsignedByte() );
                            break;
                        }
                        baReceived.length = baReceived.position;
                        baReceived.position = 0;
                        if( 1 == opcode )
                        {
                            WSReceivedTextMessage(baReceived.readUTFBytes(len));
                            baPool.Delete(baReceived);
                            baReceived = null;
                        }
                        else if( 2 == opcode )
                        {
                            WSReceivedMessage( baReceived );
                        }
                        else // 9, PING
                        {
                            WSSendBytes(baReceived,len,0x8a); // PONG sends back what PING sent
                            baPool.Delete(baReceived);
                            baReceived = null;
                        }
                    }
                    else
                    {
                        if( 1 == opcode )
                        {
                            WSReceivedTextMessage(message.readUTFBytes(len));
                        }
                        else 
                        {
                            baReceived = baPool.New();
                            message.readBytes(baReceived, 0, len );
                            if( 2 == opcode )
                            {
                                baReceived.length = len;
                                WSReceivedMessage( baReceived );
                            }
                            else // 9, PING
                            {
                                WSSendBytes(baReceived,len,0x8a); // PONG sends back what PING sent
                                baPool.Delete(baReceived);
                                baReceived = null;
                            }
                        }
                    }

                    break;
                case 8:     // Close
                    Log( "Connection closed by client." );
                    Close();
                    break;
                case 10:    // Pong
                    // We got keep-alive back
                    break;
                default:
                    Log( "Unknown opcode:", opcode );
                    // Close it.
                    Close();
                    return;
                }

                // First thing, pop the header off the message parser
                if( message.position < message.length )
                {   // Read message to its self, to shift un-parsed data to beginning
                    message.readBytes(message,0,message.length-message.position);
                    message.length -= message.position;
                    message.position = 0;
                }
                else
                {   // Clear message buffer
                    message.position = 0;
                    message.length = 0;
                }
                
            }
        }
        
        /**
         * We've fully received and decoded incoming text  
         * Do something with it.
         * @param str String containing the text
        **/
        protected function WSReceivedTextMessage( str : String ) : void
        {
            ClientBundle.Handle_WSReceivedTextMessage(this,str);
        }

        /**
         * We've fully received and decoded incoming data  
         * Do something with it.
         * @param ba ByteArray containing the data
        **/
        protected function WSReceivedMessage(ba:ByteArray) : void
        {
            ClientBundle.Handle_WSReceivedMessage(this,ba);
            WSHandled(ba);
        }
        
        /**
         * Once you've handled a binary message, be rid of it.  
         * @param ba ByteArray to be recycled
        **/
        public function WSHandled(ba:ByteArray) : void
        {
            baPool.Delete(ba);
            ba = null;
        }

        /**
         * Send binary data to client
         * @param ba Data to sen, starting at position
         * @param length to send, if other than to end of ba
        **/
        public function WSSendBytes(ba:ByteArray,len:uint = uint.MAX_VALUE,code:int=0x82):void
        {
			if( null == socket || !socket.connected || bPendingClose )
			{
			    TraceError( "Bad Socket" );
				return;
		    }
            socket.writeByte(code);
            len = Math.min(len,ba.length-ba.position);
            if( len < 126 )
            {   // Write 0..125 bytes of data
                socket.writeByte(len);
            }
            else if( len < 65536 )
            {   // Write 126..65535 bytes of data
                socket.writeByte(126);
                socket.writeShort(len);
            }
            else
            {
                socket.writeByte(127);
                socket.writeUnsignedInt(0); // No 64 bit writer, and I am not sending gigabytes
                socket.writeUnsignedInt(len);
            }
            socket.writeBytes(ba,ba.position,ba.length);
            socket.flush();
        }

        /**
         * Send text to client
         * @param str String to send
        **/
        public function WSSendText(str:String):void
        {
			if( null == socket || !socket.connected || bPendingClose )
			{
			    TraceError( "Bad Socket" );
				return;
		    }
            socket.writeByte(0x81);
            var len : uint = str.length;
            if( len < 126 )
            {   // Write 0..126 bytes of data
                socket.writeByte(len);
            }
            else if( len < 65536 )
            {   // Write 127..65535 bytes of data
                socket.writeByte(126);
                socket.writeShort(len);
            }
            else
            {
                socket.writeByte(127);
                socket.writeUnsignedInt(0); // No 64 bit writer, and I am not sending gigabytes
                socket.writeUnsignedInt(len);
            }
            socket.writeUTFBytes(str);
            socket.flush();
        }

        /**
         * We have some ByteArray that is really text, use that
         * @param ba String to send
        **/
        public function WSSendTextFromBA(ba:ByteArray,offset:uint=0,length:uint=uint.MAX_VALUE):void
        {
			if( null == socket || !socket.connected || bPendingClose )
			{
			    TraceError( "Bad Socket" );
				return;
		    }
            socket.writeByte(0x81);
            var len : uint = Math.min(ba.length-offset,length);
            if( len < 126 )
            {   // Write 0..126 bytes of data
                socket.writeByte(len);
            }
            else if( len < 65536 )
            {   // Write 127..65535 bytes of data
                socket.writeByte(126);
                socket.writeShort(len);
            }
            else
            {
                socket.writeByte(127);
                socket.writeUnsignedInt(0); // No 64 bit writer, and I am not sending terabytes, or even megabytes
                socket.writeUnsignedInt(len);
            }
            socket.writeBytes(ba,offset,len);
            socket.flush();
        }
       
        /**
         * Send a brief closing message to client
         * @param str String to send along with it
        **/
        public function WSSendError(str:String,code:int=1000):void
        {
            Log("WSSendError:",code,str);
            DoomsDayCancel();
			if( null == socket || !socket.connected || bPendingClose )
			{
			    TraceError( "Bad Socket" );
				return;
		    }
            socket.writeByte(0x88);
            if( str.length > 123 )
                str = str.substring(0,123);
            socket.writeByte(2+str.length);
            socket.writeShort(code);
            socket.writeUTFBytes(str);
            socket.flush();
            CloseWhenFinished();
        }
        

        /**
         * Scrape up a bit of info about the browser
        **/
        protected function GetBrowserDetails(header:String=""):String
        {
//CONFIG::DEBUG { Trace("GetBrowserDetails\n"+header); }
            const FindUserAgent : RegExp = new RegExp("User-Agent.*","i");
            var auser_agent : Array = header.match(FindUserAgent);
            if( null == auser_agent )
                return user_agent_short="Unknown";
            user_agent_full = auser_agent.shift();
            browser = utils.GetBrowser(user_agent_full);
            OS = utils.GetBrowserOS(user_agent_full);
            user_agent_short = browser+':'+OS;
            user_agent_short = user_agent_short.replace(/[\/ \t]/g,'');
            return user_agent_short;
        }
        
        
    }
}
