package com.pingnak
{
    import flash.utils.*;
    import flash.display.MovieClip;
    
    /**
     * A simple pool of some kind of class
     *
     * Keeps scratch allocations under control, so housekeeping is smoother
    **/
    public class WorkerPackData 
    {
        /*
         * Flags to control what kind of compression this thread does
         */

        /** Use png compression; quality is 0(slow) or 1(fast) */
        public static const bPNG          : uint = 0x00;

        /** Use jpeg compression; quality is 0-100*/
        public static const bJPEG         : uint = 0x01;
        
        /** PNG is transparent layer */
        public static const bTransparent  : uint = 0x02;

        /** Mask against previous png, and generate difference PNG */
        public static const bDelta        : uint = 0x04;

        /** Pack only visible portion, and bounding xOff/yOff are important */
        public static const bMinimum      : uint = 0x08;

        /** Base 64 encode results to text, instead of returning binary data */
        public static const bBase64       : uint = 0x10;

        /*
         * Information about data formats
         */

        /** Format to send to client */
        public static const EncoderFormatPNG : String = "data:image/png;base64,";

        /** Format to send to client */
        public static const EncoderFormatJPEG : String = "data:image/jpeg;base64,";
        
        /** One pre-encoded, single transparent pixel png. http://proger.i-forge.net/The_smallest_transparent_pixel/eBQ */
        public static const b64PNG : String = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==";

        /** One pre-encoded, single transparent pixel GIF. http://probablyprogramming.com/2009/03/15/the-tiniest-gif-ever */
        public static const b64GIF : String = "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";
        
        /** Closest I could come up with for JPEG. http://jpeg-optimizer.com/ of 1x1 jpeg: 690 bytes */
        public static const b64JPEG: String = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA6Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcgSlBFRyB2ODApLCBxdWFsaXR5ID0gMQr/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCSiiigD//Z";
    }
}
