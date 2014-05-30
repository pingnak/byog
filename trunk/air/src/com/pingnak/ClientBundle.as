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
     * Piece various web client connections into a coherent bundle, as 
     * they are identified.  We assign a unique ID to each client.html
     * we return.  This signature allows us to separate one instance
     * of the game, from other instances.  
     *
    **/
    public class ClientBundle extends Sprite
    {
        // List of all client bundles
        protected static var ClientBundles : Dictionary = new Dictionary();

        protected static const SESSION_LOAD_LOCKOUT : uint = 3000;
        protected static var ClientRequests : Dictionary = new Dictionary();
        
        // What KIND of ClientBundle to make
        public    static var ClientClass   : Class = ClientBundle;

        protected var SESSION : String;
        protected var friendly_name : String;
        protected var ccmain : ClientConnection;
        
        protected var remoteAddress : String;
        
        protected var clients : Dictionary;

        protected var resultAcc : ByteArray;

        protected var bReady : Boolean = false;
        
        public final function get active():Boolean { return bReady; }

        
        /** Get server */
        public function get server() : Server
        {
            return Server.instance;
        }
        
        /** Get 'main' socket */
        public function get socket() : Socket
        {
            if( !ready )
                return null;
            return ccmain.socket;
        }
        
        /** Get 'main' connection */
        public function get main() : ClientConnection
        {
            return ccmain;
        }

        /** Find out if our main channel is 'ready' */
        public function get ready() : Boolean
        {
            return null != ccmain && ccmain.ready;
        }

        /** Find out if we're sending to WebSocket */
        public function get bWsMode() : Boolean
        {
            return ready && ccmain.bWsMode;
        }
        
        /**
         * Iterate over client bundles
         * @param fn Function to call on each one
        **/
        public static function ForEachBundle( fn : Function ) : void
        {
            var cb : ClientBundle;
            for each( cb in ClientBundles )
            {
                fn(cb);
            }
        }

        /**
         * Iterate over client bundles, until fn returns true
         * @param fn Function to call on each one
         * @return Which one we returned on, or null, if none returned true
        **/
        public static function ForEachBundleUntil( fn : Function ) : ClientBundle
        {
            var cb : ClientBundle;
            for each( cb in ClientBundles )
            {
                if( fn(cb) )
                    return cb;
            }
            return null;
        }
        
        /**
         * Create when any ClientConnection asks for the 'main' html page
        **/
        public function ClientBundle( cc : ClientConnection, friendly : String )
        {
            clients = new Dictionary();
            // Make a unique ID, with a luggage lock bit of random
            this.ccmain = cc;
            this.friendly_name = friendly;
            this.remoteAddress = cc.socket.remoteAddress;
            
            resultAcc = new ByteArray();

            SESSION = remoteAddress+':'+((cc.socket.remotePort+Math.random()).toFixed(6));
            cc.SESSION = SESSION;
            ClientBundles[SESSION] = this;
            clients[cc] = cc;
            cc.DoomsDayCancel();
            bReady = true;
        }

        /**
         * Prevent floods of new sessions
         * Make sure it's been a little while between page loads
        **/
        public static function AllowNewSession( cc : ClientConnection ) : Boolean
        {
            try
            {
                var remoteAddress : String = cc.socket.remoteAddress;
                var tsPrev : Number = ClientRequests[remoteAddress] as Number;
                if( isNaN(tsPrev) )
                {
                    return true;
                }
                if( SESSION_LOAD_LOCKOUT > utils.TimeStamp() - tsPrev )
                {
                    return false;
                }
            }
            finally
            {
                ClientRequests[remoteAddress] = utils.TimeStamp();
            }
            return true;
        }
        

        /**
         * Find out who 'owns' this client, and attach to that
         * @param cc ClientConnection which is closing, for whatever reason
        **/
        public static function RemoveClient( cc : ClientConnection ) : void
        {
CONFIG::DEBUG { debug.Trace("ClientBundle.RemoveClient:"+cc.SESSION); }
            var cb : ClientBundle = ClientBundles[cc.SESSION];
            if( null == cb )
                return;
            delete cb.clients[cc];
            cc.SESSION = "";
            if( cc.bWsMode )
            {
CONFIG::DEBUG { debug.Trace("Was WebSocket..."); }
                // Was WebSocket connection
                cb.Close();
                return;
            }
            // Else... well, the client may be opening/closing all kinds of XMLHttpRequests.  We have to time out.
            var search : String;
            for( search in cb.clients )
            {   // Substitute with some other 'main'
                cb.ccmain = cb.clients[search];
                return;
            }
        }
        
        /**
         * Build a new ClientBundle class with app supplied version
        **/
        public static function New( cc : ClientConnection, friendly : String ) : ClientBundle
        {
            return new ClientClass( cc, friendly );
        }

        /**
         * Attempt to pick sessionid id out of url 
         * @param cc ClientConnection which asked for a resource
         * @param address A URL
         * @return false if no such ClientBundle exists (spider?)
        **/
        public static function GetSession( cc:ClientConnection, address : String ) : String
        {
            var sessionid : String = cc.SESSION;
            if( "" == sessionid )
            {   // No?  Maybe we do, in the address we received
                const rxSession : RegExp = /(\?|\&)id=[0-9:.]+/;
                var match : Array = address.match(rxSession);
                if( null != match )
                {
                    sessionid = match[0].slice(4);
                    cc.SESSION = sessionid;

                    var cb : ClientBundle = ClientBundles[cc.SESSION];
                    if( null == cb )
                    {
                        debug.Trace("GetSession Client not found",cc.SESSION);
                        return cc.SESSION = "";
                    }
                    cb.clients[cc] = cc;
                    cc.SESSION = cb.SESSION;
                    // If a connection is USED by the client, we keep it alive (unless asked to close it)
                    // We'll close the connections from this end, slaved to main connection
                    cc.DoomsDayCancel(); 
                }
                else
                {
//CONFIG::DEBUG { debug.Trace("GetSession no match",address); }
                }
            }
            return cc.SESSION;
        }
        
        /**
         * Receive some kind of http request
         * @param cc ClientConnection which asked for a resource
         * @return false if no such ClientBundle exists (spider?)
        **/
        public static function Handle_HTTPAppMessage( cc : ClientConnection, address : String, header : String, ba : ByteArray, length : uint ) : Boolean
        {
            var cb : ClientBundle = ClientBundles[cc.SESSION];
            if( null == cb )
            {
                //cc.TraceError("Handle_HTTPAppMessage missing session", cc.SESSION, address, header, ba );
                return false;
            }
            if( !cb.bReady )
                return false;
            return cb.HTTPAppMessage( cc, address, header, ba, length );
        }

        /**
         * Receive some kind of WebSocket text
         * @param cc ClientConnection which asked for a resource
         * @return false if no such ClientBundle exists (spider?), or unhandled
        **/
        public static function Handle_WSReceivedTextMessage( cc : ClientConnection, str : String ) : Boolean
        {
            var cb : ClientBundle = ClientBundles[cc.SESSION];
            if( null == cb )
            {
                cc.TraceError("Handle_WSReceivedTextMessage missing session", cc.SESSION, str );
                return false;
            }
            if( !cb.bReady )
            {
                cc.TraceError("Not ready.", cc.SESSION, str );
                return false;
            }
            return cb.WSReceivedTextMessage( cc, str );
        }

        /**
         * Receive some kind of WebSocket binary
         * @param cc ClientConnection which asked for a resource
         * @return false if no such ClientBundle exists (spider?)
        **/
        public static function Handle_WSReceivedMessage( cc : ClientConnection, ba : ByteArray ) : Boolean
        {
            var cb : ClientBundle = ClientBundles[cc.SESSION];
            if( null == cb )
            {
                cc.TraceError("Handle_WSReceivedMessage missing session", cc.SESSION, ba );
                return false;
            }
            if( !cb.bReady )
                return false;
            return cb.WSReceivedMessage( cc, ba );
        }

        /**
         * Receive some kind of http request
         * Should override to receive
         * @param cc ClientConnection which asked for a resource
         * @param address Address separated from header
         * @param header  The rest of the header
         * @param ba      Additional data attached to request
         * @param length  Abount of ba that is message 
         * @return false if unhandled
        **/
        public function HTTPAppMessage( cc : ClientConnection, address : String, header : String, ba : ByteArray, length : uint = 0 ) : Boolean
        {
            cc.TraceError("HTTPAppMessage:",address+'\n'+header,ba);
            return false;
        }

        /**
         * Receive some kind of WebSocket text
         * Should override to receive
         * @param cc ClientConnection which asked for a resource
         * @param str Data
         * @return false if unhandled
        **/
        public function WSReceivedTextMessage( cc : ClientConnection, str : String ) : Boolean
        {
            cc.TraceError("WSReceivedTextMessage",str);
            return false;
        }

        /**
         * Receive some kind of WebSocket binary
         * Should override to receive
         * @param cc ClientConnection which asked for a resource
         * @param ba Data
         * @return false if unhandled
        **/
        public function WSReceivedMessage( cc : ClientConnection, ba : ByteArray ) : Boolean
        {
            cc.TraceError("WSReceivedMessage",ba);
            return false;
        }

        /**
         * Send text to client
         * @param str String to send
        **/
        public function WSSendText(str:String):void
        {
            if( !bReady )
                return;
            if( bWsMode )
            {
                if( null == ccmain || !ccmain.ready )
                {
                    str = null;
                    TraceError( "Bad Socket" );
                    return;
                }
                ccmain.WSSendText(str);
                return;
            }
            // Accumulate xml for next response
            resultAcc.writeUTFBytes( str+"\n" );
        }
        
        /**
         * We have some ByteArray that is really text, use that
         * @param ba String to send
        **/
        public function WSSendTextFromBA(ba:ByteArray,offset:uint=0,length:uint=uint.MAX_VALUE):void
        {
            if( !bReady )
                return;
            if( bWsMode )
            {
                if( null == ccmain || !ccmain.ready )
                {
                    ba = null;
                    TraceError( "Bad Socket" );
                    return;
                }
                ccmain.WSSendTextFromBA(ba,offset,length);
                return;
            }
            // Accumulate xml for next response
            var tmp : uint = ba.position;
            ba.position = offset;
            var len : uint = Math.min(ba.bytesAvailable,length);
            resultAcc.writeUTFBytes( ba.readUTFBytes(len)+"\n" );
            ba.position = tmp;
        }

        
        /**
         * Send binary data to client
         * @param ba Data to sen, starting at position
         * @param length to send, if other than to end of ba
        **/
        public function WSSendBytes(ba:ByteArray,len:uint = uint.MAX_VALUE,code:int=0x82):void
        {
            if( !bReady )
                return;
            if( bWsMode )
            {
                if( null == ccmain || !ccmain.ready )
                {
                    ba = null;
                    TraceError( "Bad Socket" );
                    return;
                }
                ccmain.WSSendBytes(ba,len,code);
                return;
            }
            /*
            // Accumulate xml for next response
            len = Math.min(ba.bytesAvailable,length);
            var tmp : uint = ba.position;
            resultAcc.writeUTFBytes( "bin:"+utils.BytesToBase64( ba, len )+"\n" );
            ba.position = tmp;
            */
CONFIG::DEBUG { debug.ThrowAssert("Binary long poll mode disabled..."); }
        }

        /**
         * Send a brief closing message to client
         * @param str String to send along with it
        **/
        public function WSSendError( cc:ClientConnection, str:String,code:int=1000):void
        {
            TraceError("WSSendError",code,str);
            if( bWsMode )
            {
                if( null == ccmain || !ccmain.ready )
                {
                    str = null;
                    TraceError( "Bad Socket" );
                    return;
                }
                cc.WSSendError(str,code);
                return;
            }
            // Accumulate xml for next response
            resultAcc.position = 0;
            resultAcc.writeUTFBytes( "err:Error "+code+":"+str+"\n" );
            WSEmulatorCommit(cc);
            cc.CloseWhenFinished();
            setTimeout( Close, 1000 );
            bReady = false;
        }

        /** 
         * Commit emulated WebSockets xml contents to client, in answer to its query message
         * @param 
        **/
        public function WSEmulatorCommit( cc : ClientConnection ):void
        {
            if( !bReady )
                return;
            if( !cc.ready )
            {
			    TraceError( "Bad Socket" );
                resultAcc.position = 0;
                return;
            }
            var header : String = ClientConnection.Make200Header();
            header += "Content-Type: text/plain;charset=UTF-8\r\nContent-Length: " + resultAcc.position +"\r\n\r\n";
            var socket : Socket = cc.socket;
            socket.writeUTFBytes(header);
            socket.writeBytes(resultAcc,0,resultAcc.position);
            socket.flush();
            resultAcc.position = 0;
        }

        /**
         * Close ALL of my clients, if I close
        **/
        public function Close( e:Event=null ) : void
        {
            Trace("ClientBundle.Close",SESSION);
            bReady = false;

            ccmain = null;
            var a : Array = new Array();
            var cc:*;
            for( cc in clients )
            {
                a.push(cc); 
            }
            while( 0 < a.length )
            {
                cc = a.shift();
                delete clients[cc];
                cc.Close();
            }
            delete ClientBundles[SESSION];
            SESSION = "";
            
            resultAcc.clear();
            
            if( null != parent )
            {
                parent.removeChild(this);
            }
        }

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
        
    }
}
