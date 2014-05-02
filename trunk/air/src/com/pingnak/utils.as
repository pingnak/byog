
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    import flash.events.*;
    	import flash.filesystem.*;
    	import flash.geom.*;
    import flash.debugger.enterDebugger;
    
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
         * Converts a Date object to a human readable double precision time 
         * 20140405190129.03 = 2014/04/05 19:01:29, 30ms
         *
         * We waste 33 bits of 52 bits of precision, leaving 19 bits of year vs fractions of seconds in mantissa
         * 2^52 = 4503599627370496 log2(10000000000)=33 bits (second resolution), 
         * 450359 9627370496
         *   2014 0405190129 (seconds)
         * 2014 040519012900 (fractional seconds lose precision before millisecond range)
         *
         * 1/100th of a second gives us adequate resolution, down to frames, since the server runs at 30fps
         *
         * Makes a more or less functionally equivalent time stamp to 'milliseconds +/- 1970' epoch, for
         * indexing/sorting/etc., but it's readable.  Add '.toFixed(2)', to pretty print.
         * 
         * Though these stamps can't be added/subtracted directly, unlike a 'milliseconds since' value,  
         * this result can be verified to be 'valid looking'.
         *
         * As long as Number converts to 'long double', some time within the next 2000 years, this should be fine.
         * 
         * @param date Optional date object to specify time; else 'now'.
         * @return Human readable, UTC double precision floating point value
        **/
        public static function DoubleTime( date : Date = null ) : Number
        {
            if( null == date )
            {
                date = new Date();
            }
            return  (date.getUTCFullYear()  * 10000000000) + 
                    ((1+date.getUTCMonth()) * 100000000)+
                    (date.getUTCDate()      * 1000000)+
                    (date.getUTCHours()     * 10000)+
                    (date.getUTCMinutes()   * 100)+
                    (date.getUTCSeconds())+
                    Math.floor(date.getUTCMilliseconds()*0.001);
        }

        /**
         * Get year from a DoubleTime number
         * @param Number formatted with DoubleTime
         * @return Year, from trillions of years before the big bang, to trillions of years past the evaporation of all matter, without losing precision
        **/
        public static function DoubleTimeYear( dt : Number ) : Number
        {
            return Math.floor(0.0000000001 * dt);
        }
        
        /**
         * Get Month (1..12)
         * @param Number formatted with DoubleTime
         * @return Month; 1-12
        **/
        public static function DoubleTimeMonth( dt : Number ) : uint
        {
            return int(0.00000001 * dt) % 100;
        }
        
        /**
         * Get Day (1..31)
         * @param Number formatted with DoubleTime
         * @return Day of Month; 1-31
        **/
        public static function DoubleTimeDay( dt : Number ) : uint
        {
            return int(0.000001 * dt) % 100;
        }
        
        /**
         * Get Hour (0..23)
         * @param Number formatted with DoubleTime
         * @return Hour of day, in 24 hour time (0..23)
        **/
        public static function DoubleTimeHour( dt : Number ) : uint
        {
            return int(0.0001 * dt) % 100;
        }
        
        /**
         * Get Minutes (0..59)
         * @param Number formatted with DoubleTime
         * @return Minute of hour (0..59)
        **/
        public static function DoubleTimeMinute( dt : Number ) : uint
        {
            return int(0.01 * dt) % 100;
        }
        
        /**
         * Get seconds (0..59)
         * @param Number formatted with DoubleTime
         * @return Seconds (0..59)
        **/
        public static function DoubleTimeSecond( dt : Number ) : uint
        {
            return Math.floor(dt) % 100;
        }
        
        /**
         * Get fractional seconds, to whatever precision is available
         * @param Number formatted with DoubleTime
         * @return 0..(1-epsilon) 
        **/
        public static function DoubleTimeFraction( dt : Number ) : Number
        {
            return dt - Math.floor(dt);
        }

        /**
         * Check if DoubleTime value is valid-looking, and probably DoubleTime value
         * @param dt The kind of value DoubleTime makes - we assume
         * @param minYear Minimum year allowable (default to 10ms precision minimum year)
         * @param maxYear Maximum year allowable (default to 10ms precision maximum year)
        **/
        public static function IsDoubleTime( dt : Number, minYear : Number = -4500, maxYear : Number = 4500 ) : Boolean
        {
            var year : Number = Math.floor(0.0000000001 * dt);
            dt = Math.abs(dt);
            var month : int = int(0.00000001 * dt) % 100;
            var day   : int = int(0.000001 * dt) % 100;
            var hour  : int = int(0.0001 * dt) % 100;
            var minute: int = int(0.01 * dt) % 100;
            var second: int = int(dt) % 100;
            
            // Though 0 == 1BCE in astronomical calculations, calendars started at 1CE, and 1BCE.  Use '0' as check for completeness.
            return 60 > second && 60 > minute && 24 > hour && 0 < day && 31 >= day && 0 < month && 12 >= month && 0 != year && minYear <= year && maxYear >= year;
        }
        
        /**
         * Converts a DoubleTime GMT value back to Date format, for further formatting
         * @param dt The kind of value DoubleTime makes
        **/
        public static function DateFromDoubleTimeUTC( dt : Number ) : Date
        {
CONFIG::DEBUG { debug.Assert( IsDoubleTime(dt) ); }
            var year : Number = Math.floor(0.0000000001 * dt);
            dt = Math.abs(dt);
            var month : int = int(0.00000001 * dt) % 100;
            var day   : int = int(0.000001 * dt) % 100;
            var hour  : int = int(0.0001 * dt) % 100;
            var minute: int = int(0.01 * dt) % 100;
            var second: int = int(dt) % 100;
            var fraction : Number = dt-Math.floor(dt);

            var date : Date = new Date();
            date.setUTCFullYear( year, month-1, day );
            date.setUTCHours( hour, minute, second, 1000*fraction );
            return date;
        }

        /**
         * Converts a DoubleTime local value back to Date format, for further formatting
         * @param dt The kind of value DoubleTime makes
        **/
        public static function DateFromDoubleTime( dt : Number ) : Date
        {
CONFIG::DEBUG { debug.Assert( IsDoubleTime(dt) ); }
            var year : Number = Math.floor(0.0000000001 * dt);
            dt = Math.abs(dt);
            var month : int = int(0.00000001 * dt) % 100;
            var day   : int = int(0.000001 * dt) % 100;
            var hour  : int = int(0.0001 * dt) % 100;
            var minute: int = int(0.01 * dt) % 100;
            var second: int = int(dt) % 100;
            var fraction : Number = dt-Math.floor(dt);
            return new Date(year, month-1, day, hour, minute, second, 1000*fraction );
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
            rect.width = Math.floor(rect.width+0.5);
            rect.height = Math.floor(rect.height+0.5);
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
    }
}
    
