
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    import flash.events.*;
    	import flash.display.*;
    	import flash.filesystem.*;
    	import flash.geom.*;
    
    public class utils
    {
        public static const RAD2DEG : Number = 180/Math.PI;
        public static const DEG2RAD : Number = Math.PI/180;
        public static const PIx2    : Number = Math.PI+Math.PI;
        public static const origin : Point = new Point(0,0);
        
        
        /** Get milliseconds since 1/1/1970, 00:00:00, UTC */
        public static function TimeStamp() : Number
        {
            return (new Date()).time;
        }
        
        /**
         * Encode data to Base64 format, from current byteArray seek position
         * For some reason, over-engineered flex SDK byte array class is missing from AIR/Flash build
         * @param ba ByteArray to encode
         * @param offset Where in array to encode (default:from beginning)
         * @param length How much to encode (default:to end)
         * @return String of Base64 data, without line breaks of what you told it to
        **/
        public static function BytesToBase64( ba:ByteArray, length:uint = uint.MAX_VALUE ) : String
        {
            //const encodes : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            const encodes : Vector.<int> = new <int>[
                65,66,67,68,69,70,71,72,73,74,  // A-Z
                75,76,77,78,79,80,81,82,83,84,
                85,86,87,88,89,90,
                 97, 98, 99,100,101,102,103,104,105,106, //a-z
                107,108,109,110,111,112,113,114,115,116,
                117,118,119,120,121,122,
                48,49,50,51,52,53,54,55,56,57, // 0-9
                43,47]; // +/
            const result : ByteArray = new ByteArray(); // Reuse ByteArray
            var remains : uint = Math.min( ba.length-ba.position, length );
            result.length = Math.ceil((2 + remains - ((remains + 2) % 3)) * 4 / 3);
            var index : int = 0;
            var shift : uint;
            while( 3 <= remains )
            {
                shift =  (ba.readByte()&0xff) << 16;
                shift |= (ba.readByte()&0xff) << 8;
                shift |= (ba.readByte()&0xff);
                result[index++] = encodes[shift>>>18];
                result[index++] = encodes[(shift>>>12) & 0x3f];
                result[index++] = encodes[(shift>>>6) & 0x3f];
                result[index++] = encodes[shift & 0x3f];
                remains -= 3;
            }
            if( 2 == remains )
            {
                shift =  (ba.readByte()&0xff) << 16;
                shift |= (ba.readByte()&0xff) << 8;
                result[index++] = encodes[shift>>>18];
                result[index++] = encodes[(shift>>>12) & 0x3f];
                result[index++] = encodes[(shift>>>6) & 0x3f];
                result[index++] = 61;
            }
            else if( 1 == remains )
            {
                shift = (ba.readByte()&0xff) << 16;
                result[index++] = encodes[shift>>>18];
                result[index++] = encodes[(shift>>>12) & 0x3f];
                result[index++] = 61;
                result[index++] = 61;
            }
            return result.readUTFBytes(index);
        }

        /** 
         * Converts a Date object to an RFC822-formatted string (GMT/UTC).
         * @param date Date to format, or null, if you want 'now'
        **/
        public static function RFC822_Time( date : Date = null ):String 
        {
            if( null == date )
                date = new Date();
            const awday : Vector.<String> = new <String>["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
            const amonth : Vector.<String> = new <String>["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            return awday[int(date.dayUTC%7)]+", "+
                   (date.dateUTC < 10 ? "0"+date.dateUTC : date.dateUTC.toString())+" "+
                   amonth[date.monthUTC]+" "+
                   date.fullYearUTC+" "+
                   (date.hoursUTC < 10 ? "0"+date.hoursUTC : date.hoursUTC.toString())+":"+
                   (date.minutesUTC < 10 ? "0"+date.minutesUTC : date.minutesUTC.toString())+":"+
                   (date.secondsUTC < 10 ? "0"+date.minutesUTC : date.minutesUTC.toString())+
                   " GMT";
        }
        
        /**
         * Try to fish browser/version out of user-agent line
         * As is typical for all things web technology, a complete disaster
        **/
        public static function GetBrowser(user_agent:String):String
        {
            // Try by matching browser name
            const rxIsOpera  : RegExp = new RegExp("^Opera/[0-9.]+","gx");
            const rxIsChrome : RegExp = new RegExp("(Chrome/[0-9.]+|Chromium/[0-9.]+)","gx");
            const rxIsSilk   : RegExp = new RegExp("Silk/[0-9.]+","gx");
            const rxIsFirefox: RegExp = new RegExp("Firefox/[0-9.]+$","gx");
            const rxIsMSIE   : RegExp = new RegExp("MSIE[0-9.]+","gx");
            const rxIsSafari : RegExp = new RegExp("Safari/[0-9.]+","gx");
            const rxIsSeaMonkey:RegExp= new RegExp("SeaMonkey/[0-9.]+","gx");
            const rxIsBlackberry:RegExp= new RegExp("Blackberry[0-9./]+","gx");
            var match : String;
            match = ShortestMatch( user_agent.match(rxIsOpera) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsChrome) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsSilk) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsFirefox) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsMSIE) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsSafari) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsBlackberry) );
            if( "" != match )
                return match;

            // Try by inference.  Why do they insist on practically encrypting these details
            const rxIsIOSDevice: RegExp = new RegExp("(iPad;|iPod;|iPhone;|iOS)","gx");
            match = ShortestMatch( user_agent.match(rxIsIOSDevice) );
            if( "" != match )
            {
                return "Safari";
            }
            
            debug.Log("GetBrowser Fallback",user_agent);
                
            // Try by family
            const rxIsGecko  : RegExp = new RegExp("Gecko/[0-9.]+","igx");
            const rxIsTrident: RegExp = new RegExp("Trident/[0-9.]+","igx");
            const rxIsWebKit : RegExp = new RegExp("WebKit/[0-9.]+","igx");
            const rxIsKHTML  : RegExp = new RegExp("KHTML/[0-9.]+","igx");
            const rxIsBlink  : RegExp = new RegExp("Blink/[0-9.]+","igx");
            match = ShortestMatch( user_agent.match(rxIsGecko) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsTrident) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsWebKit) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsKHTML) );
            if( "" != match )
                return match;
            match = ShortestMatch( user_agent.match(rxIsBlink) );
            if( "" != match )
                return match;

            debug.Log("GetBrowser Fail",user_agent);

            // I give up.
            return "Unknown Browser";
        }
        /**
         * Try to fish OS/version out of user-agent line
         * As is typical for all things web technology, a complete disaster
        **/
        public static function GetBrowserOS(user_agent:String):String
        {
            var match : String;
            const rxIsAndroid  : RegExp = new RegExp("Android.*?[0-9.]+","gx");
            match = ShortestMatch( user_agent.match(rxIsAndroid) );
            if( "" != match )
                return match;
            const rxIsWindows  : RegExp = new RegExp("Windows[0-9.]+","gx");
            match = ShortestMatch( user_agent.match(rxIsWindows) );
            if( "" != match )
                return match;
            const rxIsOSX      : RegExp = new RegExp("(OS X|OSX)[ \t]*[0-9_.]+","g");
            match = ShortestMatch( user_agent.match(rxIsOSX) );
            if( "" != match )
                return match;
            const rxIsIOSDevice: RegExp = new RegExp("(iPad;|iPod;|iPhone;|iOS)","gix");
            match = ShortestMatch( user_agent.match(rxIsIOSDevice) );
            if( "" != match )
            {
                const rxiOSVersion: RegExp = new RegExp("OS [0-9_.]+","g");
                return match+ShortestMatch( user_agent.match(rxiOSVersion) );
            }
            const rxIsBlackberry:RegExp = new RegExp("BlackBerry[0-9./]+","g");
            match = ShortestMatch( user_agent.match(rxIsBlackberry) );
            if( "" != match )
                return match;
            const rxIsRIM      : RegExp = new RegExp(" RIM .*?","g");
            match = ShortestMatch( user_agent.match(rxIsRIM) );
            if( "" != match )
            {
                match = ShortestMatch( match.match(/OS [0-9_.]+/g) );
                return "RIM"+match;
            }
            
            // Linux needs to follow android...
            const rxIsLinux    : RegExp = new RegExp("Linux","ig");
            match = ShortestMatch( user_agent.match(rxIsLinux) );
            if( "" != match )
                return match;

            debug.Log("GetBrowserOS Fail",user_agent);
                
            // I give up.
            return "Unknown";
        }

        /**
         * @private
         * Where multiple results are found, pick the 'shorter' one
        **/
        private static function ShortestMatch(matches:Array) : String
        {
            var i : int;
            var lentobeat : uint = uint.MAX_VALUE;
            var szToBeat : String = "";
            var curr : String;
            for( i = 0; i < matches.length; ++i )
            {
                curr = matches[i];
                if( curr.length < lentobeat )
                {
                    lentobeat = curr.length;
                    szToBeat = curr;
                }
            }
            return szToBeat;
        }

        /** Get extension from file, with '.' still on it */
        public static function File_extension( file : File ) : String
        {
            var url : String = file.url;
            var index : int = url.lastIndexOf('.');
            if( -1 == index )
                return "";
            return decodeURI(url.slice(index));
        }

        /** Name of file File without extension */
        public static function File_name( file : File ) : String
        {
            var url : String = File_nameext(file);
            var index : int = url.lastIndexOf('.');
            if( -1 == index )
                return url;
            return decodeURI(url.slice(0,index));
        }
        
        /** Name of file File and extension */
        public static function File_nameext( file : File ) : String
        {
            var url : String = file.url;
            var index : int = url.lastIndexOf('/');
            if( -1 == index )
                return "";
            return decodeURI(url.slice(1+index));
        }
        
        /** Center a rectangle in/over another one */
        public static function RectCenterIn( rToCenter : Rectangle, rIn : Rectangle ) : Rectangle
        {
            rToCenter.x = rIn.x + Math.floor(0.5*(rIn.width  - rToCenter.width));
            rToCenter.y = rIn.y + Math.floor(0.5*(rIn.height - rToCenter.height));
            return rToCenter;
        }

        /** Center a rectangle in/over another one */
        public static function RectCenterPt( rToCenter : Rectangle, x:Number, y:Number ) : Rectangle
        {
            rToCenter.x = x - Math.floor(0.5*rToCenter.width);
            rToCenter.y = y - Math.floor(0.5*rToCenter.height);
            return rToCenter;
        }

        /** Snap a rectangle to integer boundaries */
        public static function SnapRect( rect : Rectangle ) : Rectangle
        {
            rect.x = Math.floor(rect.x);
            rect.y = Math.floor(rect.y);
            rect.width = Math.ceil(rect.width);
            rect.height = Math.ceil(rect.height);
            return rect;
        }

        /** Scale a rectangle */
        public static function RectScale( rect : Rectangle, scale : Number ) : Rectangle
        {
            rect.x *= scale;
            rect.y *= scale;
            rect.width *= scale;
            rect.height *= scale;
            return rect;
        }
        
        /** Snap a rectangle to integer boundaries */
        public static function SnapPoint( pt : Point ) : Point
        {
            pt.x = Math.floor(pt.x);
            pt.y = Math.floor(pt.y);
            return pt;
        }
        
        public static function FixDeg(deg:Number):Number
        {
            if( deg < 0 )
                return 360-((-deg) % 360);
            return deg % 360;
        }

        public static function Rad2Deg(rad:Number):Number
        {
            return FixDeg(RAD2DEG * rad);
        }

        public static function Deg2Rad(deg:Number):Number
        {
            return FixDeg(deg) * DEG2RAD;
        }
        
        /** Return +/-1 for which way rotation should happen */
        public static function NearestAngle( radStart:Number, radFinish:Number ) : Number
        {
            return Math.atan2(Math.sin(radFinish-radStart), Math.cos(radFinish-radStart));
        }
        
        /** Parse a boolean string to a Boolean value */
        public static function parseBoolean(b:*):Boolean
        {
            if( b is String )
            {
                var i : int = int(b);
                if( 0 != i )
                    return true;
                switch(b.match(/[a-z]+/i))
                {
                case "true":
                case "yes":
                case "on":
                    return true;
                default:
                    return 0 != int(b);
                }
            }
            else if( b is Boolean )
            {
                return b;
            }
            else if( b is Number )
            {
                return 0 != b;
            }
            return false;
        }
        
        /** 
         * Shuffle an array in place
         * @param a Array to shuffle
         * @return Same instance of array, shuffled 
        **/
        public static function Shuffle( a:Array, iterations : int = 3 ) : Array
        {
            var curr : int;
            var tmp : *;
            var rindex : int;
            while( 0 < iterations-- )
            {
                curr = a.length;
                while( 0 < curr-- )
                {
                    tmp = a[curr];
                    rindex = int(Math.random() * a.length);
                    a[curr] = a[rindex];
                    a[rindex] = tmp;
                }
            }
            return a;
        }
        
        /**
         * Perform a breadth-first callback of display objects
         * This finds everything in order, from lowest depth, to topmost.
         *
         * @param dobj Start of DisplayObject tree search 
         * @param callback Function() : Boolean - return true to stop at current display object
         * @return DisplayObject that callback stopped at, or null if we recursed all and didn't find it
        **/
        public static function DObjBreadthFirst( dobj : DisplayObject, callback : Function ) : DisplayObject
        {
CONFIG::DEBUG { debug.Assert( null != dobj ); }
CONFIG::DEBUG { debug.Assert( null != callback ); }
            var dCurr : DisplayObject;
            var dContain : DisplayObjectContainer;
            var i : int;
            var fifo : Array = new Array();
            fifo.push(dobj);
            while( 0 != fifo.length )
            {
                dCurr = fifo.shift(); // Remove earliest entries, first
                if( callback(dCurr) )
                    return dCurr;
                if( dCurr is DisplayObjectContainer )
                {
                    dContain = dCurr as DisplayObjectContainer;
                    for( i = 0; i < dContain.numChildren; ++i )
                    {
                        fifo.push(dContain.getChildAt(i));
                    }
                }
            }
            return null;
        }
        
        /**
         * Perform a recursive, depth-first callback of display objects
         * @param dobj Start of DisplayObject tree search 
         * @param callback Function() : Boolean - return true to stop at current display object
         * @return DisplayObject that callback stopped at, or null if we recursed all and didn't find it
        **/
        public static function DObjDepthFirst( dobj : DisplayObject, callback : Function ) : DisplayObject
        {
CONFIG::DEBUG { debug.Assert( null != dobj ); }
CONFIG::DEBUG { debug.Assert( null != callback ); }
            var dContain : DisplayObjectContainer;
            var dCurr : DisplayObject;
            var i : int;
            if( dobj is DisplayObjectContainer )
            {
                dContain = dobj as DisplayObjectContainer;
                for( i = 0; i < dContain.numChildren; ++i )
                {
                    dCurr = DObjDepthFirst(dContain.getChildAt(i),callback);
                    if( null != dCurr )
                        return dCurr;
                }
            }
            if( callback(dobj) )
                return dobj;
            return null;
        }

        /**
         * Find a DisplayObject by name
         * 
         * This is the naiive case for finding things in a MovieClip that doesn't
         * have multiple copies of things to confuse a search for something.
         *
         * @param dobj Start of DisplayObject tree search 
         * @param label Name of object to find
         * @return DisplayObject that matched, or null if we didn't find it
        public static function DObjFind( dobj : DisplayObject, label : String ) : DisplayObject
        {
            function foundIt(dobj:DisplayObject) : Boolean
            {
                return dobj.name == label;
            }
            return DObjBreadthFirst( dobj, foundIt );
        }
        **/
        
        /**
         * Find a DisplayObject by hinted '.' path
         *
         * Basically, if we re-arrange the contents of a MovieClip, this will 
         * tend to find children of children without worrying overmuch about the 
         * absolute path to them, or naming every step to find them, such as 
         * reuse cases for a MovieClip.
         *
         * In the case where we have mc.balloon.moo.face.(unnamed).skeleton.hotpt...
         *      DObjFind(mc,"moo") would find 'moo'
         *      DObjFind(mc,"moo.hotpt") would find 'moo', then find 'hotpt' in moo.
         *
         * We do this because more than one thing might have 'hotpt' in it, so we
         * need to be somewhat specific for those cases.
         *
         * @param dobj Start of DisplayObject tree search 
         * @param label Name of object to find
         * @return DisplayObject that matched, or null if we didn't find it
        **/
        public static function DObjFindPath( dobj : DisplayObject, label : String ) : DisplayObject
        {
            var asplit : Array = label.split('.');
            var labelcurr : String;
            while( asplit.length )
            {
                labelcurr = asplit.shift();
                dobj = DObjBreadthFirst( dobj, foundIt );
                if( null == dobj )
                    return null;
            }
            function foundIt(dobjCurr:DisplayObject) : Boolean
            {
                return dobjCurr.name == labelcurr;
            }
            return dobj;
        }

        /**
         * Find a MovieClip in dobj, and put consistent debug checking here.
         * @param dobj Start of DisplayObject tree search 
         * @param label Name of object to find
         * @return MovieClip with DObjFindPath; cast to MovieClip and assert success
        **/
        public static function FindMC( dobj : DisplayObject, label : String ) : MovieClip
        {
            var ret : MovieClip = DObjFindPath(dobj,label) as MovieClip;
            // We want to 'guarantee' a result; null will still be a crash in release mode, if you let it go that far 
CONFIG::DEBUG { debug.Assert( null != ret ); }
            return ret;
        }
    }
}
   
