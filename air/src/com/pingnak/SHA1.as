/**
 * SHA1 hash, so html5 WebSock client can connect to my dumb server.
 *
 * Draft RFC6455 calls for this, along with some other flaming hoops, to get 
 * a web client connected to my 'trivial' server.  But I don't want a whole 
 * 'cryptology' library, just to do this, nor do I wish to figure out how
 * to jam a whole render+animation library into an existing web server.
 *
 * Worse still, for this useless step, RFC6455 will probably keep changing
 * out from under me from time to time, for years and years.  Still, since 
 * I'm attempting to avoid a purpose-built web client for every app, it seems 
 * a small price to pay... perhaps. 
 *
 * So anyway, I must hack something together from other functions and examples.
 *
**/

/* Since I snipped from 

   https://github.com/mikechambers/as3corelib
   
   I am compelled to include their copyright.  Mostly I stripped the external
   library dependencies and beat in a few local equivalents.

  Copyright (c) 2008, Adobe Systems Incorporated
  All rights reserved.

  Redistribution and use in source and binary forms, with or without 
  modification, are permitted provided that the following conditions are
  met:

  * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
  
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the 
    documentation and/or other materials provided with the distribution.
  
  * Neither the name of Adobe Systems Incorporated nor the names of its 
    contributors may be used to endorse or promote products derived from 
    this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.pingnak
{
    import flash.utils.ByteArray;

    /**
     * Utility base class, to make reusing some of the bits and pieces easier
    **/
    public class SHA1
    {
        /**
         * Calculate SHA-1 at current byte array seek position, over 'length' bytes
         * @param ba Data to make an SHA-1 hash from
         * @param length Limit length used in ba
         * @return String containing 40 magic hexadecimal digits 
        **/
        public static function Calculate( ba : ByteArray, length : uint = uint.MAX_VALUE ) : ByteArray
        {
			var blocks:Array = SHA1.createBlocksFromByteArray( ba, length );
			return SHA1.hashBlocks(blocks);
        }

        /**
         * Calculate SHA-1 from a string.
         * @param string String to make SHA-1 from
         * @return String containing 40 magic hexadecimal digits 
        **/
        public static function FromString( string : String ):ByteArray
        {
            var ba : ByteArray = new ByteArray();
            ba.writeUTFBytes(string);
            ba.position = 0;
            return Calculate( ba );
        }

        
        /** Do the complicated and technical stuff */
		private static function hashBlocks( blocks:Array ):ByteArray
		{
			// initialize the h's
			var h0:uint = 0x67452301;
			var h1:uint = 0xefcdab89;
			var h2:uint = 0x98badcfe;
			var h3:uint = 0x10325476;
			var h4:uint = 0xc3d2e1f0;
			
			var len:int = blocks.length;
			var w:Array = new Array( 80 );
			var temp:uint;
			
			// loop over all of the blocks
			for ( var i:int = 0; i < len; i += 16 ) {
			
				// 6.1.c
				var a:uint = h0;
				var b:uint = h1;
				var c:uint = h2;
				var d:uint = h3;
				var e:uint = h4;
				
				// 80 steps to process each block
				var t:int;
				for ( t = 0; t < 20; t++ ) {
					
					if ( t < 16 ) {
						// 6.1.a
						w[ t ] = blocks[ i + t ];
					} else {
						// 6.1.b
						temp = w[ t - 3 ] ^ w[ t - 8 ] ^ w[ t - 14 ] ^ w[ t - 16 ];
						w[ t ] = ( temp << 1 ) | ( temp >>> 31 )
					}

					// 6.1.d
					temp = ( ( a << 5 ) | ( a >>> 27 ) ) + ( ( b & c ) | ( ~b & d ) ) + e + int( w[ t ] ) + 0x5a827999;

					e = d;
					d = c;
					c = ( b << 30 ) | ( b >>> 2 );
					b = a;
					a = temp;
				}
				for ( ; t < 40; t++ )
				{
					// 6.1.b
					temp = w[ t - 3 ] ^ w[ t - 8 ] ^ w[ t - 14 ] ^ w[ t - 16 ];
					w[ t ] = ( temp << 1 ) | ( temp >>> 31 )

					// 6.1.d
					temp = ( ( a << 5 ) | ( a >>> 27 ) ) + ( b ^ c ^ d ) + e + int( w[ t ] ) + 0x6ed9eba1;

					e = d;
					d = c;
					c = ( b << 30 ) | ( b >>> 2 );
					b = a;
					a = temp;
				}
				for ( ; t < 60; t++ )
				{
					// 6.1.b
					temp = w[ t - 3 ] ^ w[ t - 8 ] ^ w[ t - 14 ] ^ w[ t - 16 ];
					w[ t ] = ( temp << 1 ) | ( temp >>> 31 )
					
					// 6.1.d
					temp = ( ( a << 5 ) | ( a >>> 27 ) ) + ( ( b & c ) | ( b & d ) | ( c & d ) ) + e + int( w[ t ] ) + 0x8f1bbcdc;
					
					e = d;
					d = c;
					c = ( b << 30 ) | ( b >>> 2 );
					b = a;
					a = temp;
				}
				for ( ; t < 80; t++ )
				{
					// 6.1.b
					temp = w[ t - 3 ] ^ w[ t - 8 ] ^ w[ t - 14 ] ^ w[ t - 16 ];
					w[ t ] = ( temp << 1 ) | ( temp >>> 31 )

					// 6.1.d
					temp = ( ( a << 5 ) | ( a >>> 27 ) ) + ( b ^ c ^ d ) + e + int( w[ t ] ) + 0xca62c1d6;

					e = d;
					d = c;
					c = ( b << 30 ) | ( b >>> 2 );
					b = a;
					a = temp;
				}
				
				// 6.1.e
				h0 += a;
				h1 += b;
				h2 += c;
				h3 += d;
				h4 += e;		
			}
			
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeInt(h0);
			byteArray.writeInt(h1);
			byteArray.writeInt(h2);
			byteArray.writeInt(h3);
			byteArray.writeInt(h4);
			byteArray.position = 0;
			
			return byteArray;
		}
        
        /**
         *  @private
         *  Converts a ByteArray to a sequence of 16-word blocks
         *  that we'll do the processing on.  Appends padding
         *  and length in the process.
         *
         *  @param data		The data to split into blocks; position seeked where you want to begin
         *  @param length	Optionally limit how much of the ByteArray to use, after position
         *  @return			An array containing the blocks into which data was split
         */
        private static function createBlocksFromByteArray( data:ByteArray, length : uint = uint.MAX_VALUE ):Array
        {
            var oldPosition:int = data.position;
            
            var blocks:Array = new Array();
            var len:int = Math.min(data.length,length) * 8;
            
            var mask:int = 0xFF; // ignore hi byte of characters > 0xFF
            for( var i:int = 0; i < len; i += 8 )
            {
                blocks[ i >> 5 ] |= ( data.readByte() & mask ) << ( 24 - i % 32 );
            }
            
            // append padding and length
            blocks[ len >> 5 ] |= 0x80 << ( 24 - len % 32 );
            blocks[ ( ( ( len + 64 ) >> 9 ) << 4 ) + 15 ] = len;
            
            data.position = oldPosition;

            return blocks;
        }
        
    }
}
