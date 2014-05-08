
package com.pingnak
{
    import flash.system.*;
    import flash.events.*;
    import flash.utils.*;
    	import flash.filesystem.*;
    	import flash.geom.*;
    
    /**
     * Just a dumping ground for 'miscellaneous'.
    **/
    public class utils
    {
        public static const RAD2DEG : Number = 180/Math.PI;
        public static const DEG2RAD : Number = Math.PI/180;
        public static const PIx2    : Number = Math.PI+Math.PI;
        public static const origin  : Point = new Point(0,0);
        
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
         * These stamps can't be added/subtracted directly, unlike a 'milliseconds since' value,  
         * this result can be verified to be 'valid looking', in code.
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
        
    }
}
    
