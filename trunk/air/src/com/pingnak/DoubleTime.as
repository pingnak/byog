
package com.pingnak
{
    import flash.system.*;
    import flash.utils.*;
    
    public class DoubleTime
    {
        
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
        public static function Get( date : Date = null ) : Number
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
        public static function Year( dt : Number ) : Number
        {
            return Math.floor(0.0000000001 * dt);
        }
        
        /**
         * Get Month (1..12)
         * @param Number formatted with DoubleTime
         * @return Month; 1-12
        **/
        public static function Month( dt : Number ) : uint
        {
            return int(0.00000001 * dt) % 100;
        }
        
        /**
         * Get Day (1..31)
         * @param Number formatted with DoubleTime
         * @return Day of Month; 1-31
        **/
        public static function Day( dt : Number ) : uint
        {
            return int(0.000001 * dt) % 100;
        }
        
        /**
         * Get Hour (0..23)
         * @param Number formatted with DoubleTime
         * @return Hour of day, in 24 hour time (0..23)
        **/
        public static function Hour( dt : Number ) : uint
        {
            return int(0.0001 * dt) % 100;
        }
        
        /**
         * Get Minutes (0..59)
         * @param Number formatted with DoubleTime
         * @return Minute of hour (0..59)
        **/
        public static function Minute( dt : Number ) : uint
        {
            return int(0.01 * dt) % 100;
        }
        
        /**
         * Get seconds (0..59)
         * @param Number formatted with DoubleTime
         * @return Seconds (0..59)
        **/
        public static function Second( dt : Number ) : uint
        {
            return Math.floor(dt) % 100;
        }
        
        /**
         * Get fractional seconds, to whatever precision is available
         * @param Number formatted with DoubleTime
         * @return 0..(1-epsilon) 
        **/
        public static function Fraction( dt : Number ) : Number
        {
            return dt - Math.floor(dt);
        }

        /**
         * Check if DoubleTime value is valid-looking, and probably DoubleTime value
         * @param dt The kind of value DoubleTime makes - we assume
         * @param minYear Minimum year allowable (default to 10ms precision minimum year)
         * @param maxYear Maximum year allowable (default to 10ms precision maximum year)
        **/
        public static function Validate( dt : Number, minYear : Number = -4500, maxYear : Number = 4500 ) : Boolean
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
        public static function GetUTC( dt : Number ) : Date
        {
CONFIG::DEBUG { debug.Assert( Validate(dt) ); }
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
        public static function GetDate( dt : Number ) : Date
        {
CONFIG::DEBUG { debug.Assert( Validate(dt) ); }
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
        
    }
}
   
