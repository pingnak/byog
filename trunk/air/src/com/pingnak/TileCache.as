
package com.pingnak
{
    import flash.net.*;
    import flash.system.*;
    import flash.utils.*;
    import flash.events.*;
    import flash.display.*;
    import flash.geom.*;
    	import flash.filesystem.*;
    
    import com.pingnak.*;

    /**
     * We need a background (and possibly overhead) image for the wander-about
     * 
     * I want:
     *    Cached on the client for some distance around players
     *    Incremental updates, whenever possible.
     *    Mutable doors/passages (e.g. change background when a user opens a door)
     *    Stamps (e.g. kill a zombie, add it to background)
     *
     * Foreground imagery:
     *    Roof/structure that becomes alpha-transparent, when users move under it, 
     *    Overhanging trees that don't block view
     *    
     *
     * No slipping/de-syncing.  Pan about, around user's character (until character reaches edges)
     *
     * Invalidate
     * 
     * WC -> wc World Coordinate -> window coordinate
     * 
     * posn,id,x,y              Set client background position
     * tile,id,tid,png          Add client background tile
     * free,id,tid,[,tid...]    Forget client background tile(s)
     * kill,id                  Forget client cache completely
     * 
    **/
    public class TileCache
    {
        
        /** Change client pan position in buffer, to compensate for bounding box and/or scrolling */
        public static const TC_POSN : String =   "posn";
        
        /** Send tile data */
        public static const TC_TILE : String =   "tile";

        /** Note: If you change these, update WCTileID; note power of 2 */
        public var TILE_WIDE : int = 50;
        public var TILE_HIGH : int = 50;

        /** Reduce the number of tiles to throw at the client at the same time */
        public static const MAX_TILES_FRAME : int = 2;
        
        protected var id : String;
        protected var bm : BitmapData;

        /** Clock signature for this round of updates */
        protected var tick : Number;
        
        /** Map of tiles */
        protected var tiles : Dictionary;
        
        /** Convert x,y in tile ID coordinates to a tile dictionary ID */
        public static function TileID(x:int,y:int) : String
        {
            return x.toString()+','+y.toString();
        }

        /** Convert tile dictionary ID to coordinates */
        public static function TilePos(id:String,pt:Point = null) : Point
        {
            if( null == pt )
                pt = new Point();
            var a : Array = id.split(',');
            pt.x = a[0];
            pt.y = a[1];
            return pt;
        }
        
        /**
         * Construct from a single bitmap.  
         * We chop it into tiles, and pre-pack them all for sending to the clients 
        **/
        public function TileCache( id : String, wide : int, high : int )
        {
            this.id = id;
            TILE_WIDE = wide;
            TILE_HIGH = high;
            tiles = new Dictionary();
        }

        /**
         * Generate from a folder full of pre-processed, already compressed images 
        **/
        public function FromRendered( folder : File ) : void
        {
            Tick();
            trace("TileCache.FromRendered",folder.nativePath);
            var i:uint;
            var list:Array = folder.getDirectoryListing();
            var file : File;
            var filename : String;
            var fs : FileStream = new FileStream();
            var baFile : ByteArray = new ByteArray();
            var asplit : Array;
            var td : TileData;
            var idCurr : String;
            for (i = 0; i < list.length; i++) 
            {
                file = list[i];
                if( ".png" == utils.File_extension(file) )
                {
                    fs.open(file,FileMode.READ);
                    fs.readBytes(baFile);
                    fs.close();
                    filename = utils.File_name(file);
                    asplit = filename.split('_');
                    baFile.position = 0;
                    idCurr = TileID(int(asplit[1]),int(asplit[2]));
                    td = new TileData(this,tick,idCurr, WorkerPackData.EncoderFormatPNG + utils.BytesToBase64( baFile ));
                    // Pre-base64 encode the tiles, to minimize work of sending them to web client
                    //trace(filename,idCurr,td);
                    tiles[idCurr] = td;
                }
            }            
        }
        
        /**
         * Generate from one, mutable image
        **/
        public function FromBitmap( bm : BitmapData ) : void
        {
            // Re-render map
            Dirty(bm.rect);
        }


        // Update time stamp for another round of play
        public function Tick() : Number
        {
            return tick = (new Date()).getTime();
        }
        
        /**
         * Mark a portion of the map 'dirty', and re-render it
        **/
        protected function Dirty( rect : Rectangle ) : void
        {
            const encoder : PNGEncoderOptions = new PNGEncoderOptions(false); // Changes to map will be less frequent, but map data gets big, fast.
            const origin : Point = new Point(0,0);
            
            var left : int = Math.floor(rect.left / TILE_WIDE) * TILE_WIDE;
            var top :  int = Math.floor(rect.top / TILE_HIGH) * TILE_HIGH;
            var right : int = Math.ceil(rect.right / TILE_WIDE) * TILE_WIDE;
            var bottom : int = Math.ceil(rect.bottom / TILE_HIGH) * TILE_HIGH;
            var rCurr : Rectangle = new Rectangle(left,top,TILE_WIDE,TILE_HIGH);
            var bmCurr : BitmapData = new BitmapData(TILE_WIDE,TILE_HIGH, bm.transparent, 0 );
            var baCurr : ByteArray = new ByteArray();
            var idCurr : String;
            var pngData: String;

            // Iterate over region and make new Base64 encoded PNG data for each tile
            var row : int;
            var col : int;
            var px : int;
            var py : int;

            // Move the clock forward
            Tick();

            row = 0;
            for( py = top; py < bottom; py += TILE_HIGH )
            {
                col = 0;
                rCurr.y = py;
                for( px = left; px < right; px += TILE_WIDE )
                {
                    rCurr.x = px;
                    if( bmCurr.transparent )
                        	bmCurr.fillRect(bmCurr.rect, 0);
                    bmCurr.copyPixels(bm, rCurr, origin);
                    // TODO: Re-encode in worker thread, only update tile map when re-encoded
                    baCurr.position = 0;
                    bmCurr.encode(bmCurr.rect,PNGEncoderOptions,baCurr);
                    baCurr.length = baCurr.position;
                    baCurr.position = 0;
                    pngData = WorkerPackData.EncoderFormatPNG + utils.BytesToBase64(baCurr);
                    idCurr = TileID(col,row);
                    tiles[idCurr] = new TileData(this,tick,idCurr,pngData);
                    col++;
                }
                row++;
            }
        }
        
        /**
         * Draw to the image, and keep track of difference  
        **/
        public function DrawTo( dobj : DisplayObject, x : int, y : int, scale:Number=1, rotate:Number=0 ) : void
        {
        }
        

        /**
         * Wipe cache on client
        **/
        public function Purge( cb : ClientBundle, layer : TileLayer ) : void
        {
            // Client: Forget cache
            cb.WSSendText("tile,nuke");

            // Take cache apart, to make sure the parts are freed
            // Flash 'gives up' after a certain amount of house cleaning
            var idCurr : String;
            var curr : TileData;
            var rid : Array = new Array();
            for( idCurr in layer.tiles )
            {
                // Add to eliminate message, and eliminate
                rid.push(idCurr);
            }
            while( 0 != rid.length )
            {
                delete layer.tiles[rid.pop()];
            }
        }
        
        /**
         * Given current position, and recorded info about tiles, compose a set of commands
         * for the client, to recalculate, pan, update local tile map.
         * 
         * @param cb Client info/connection to update 
         * @param layer Client layer details to update
         * @param max Maximum number of tiles to send
        **/
        public function Update( cb : ClientBundle, layer : TileLayer, max : uint = MAX_TILES_FRAME ) : void
        {
            /*
            if( layer.prev_position.equals( layer.position ) )
            {   // Don't re-render same thing, when not moving/changing
                return;
            }
            */
            /*
               +-------------------------+
               |        Cache limit      |
               |  +-------------------+  |
               |  |      Loading      |  |
               |  |  +-------------+  |  |
               |  |  |    Ready    |  |  |
               |  |  |  +-------+  |  |  |
               |  |  |  |Visible|  |  |  |
               |  |  |  +-------+  |  |  |
               |  |  |    Ready    |  |  |
               |  |  +-------------+  |  |
               |  |      Loading      |  |
               |  +-------------------+  |
               |        Cache limit      |
               +-------------------------+
               
               We have several boundaries to consider...
               What's visible, now
               What's ready to be seen on the client, if they move around in any direction
               What should be preloading on the client, with emphasis given to direction of motion
               What should be culled on the client, to keep it from remembering too much
               What has changed on the map, since the client was last refreshed
               
               This boils down to basically, what we need to send to the client, and what we need
               to delete from the client, because it's too far away, and we have difficult decisions
               to make about memory consumption, and javascript memory housekeeping sucks.
               
               * What's inside the loading limit, that we haven't sent, or need to update.  TBD: Sane limit.

               * What's outside the cache limit, that needs to go away.  TBD: Sane limit.
               
               The client will slavishly draw wherever we tell it to, whether or not there are images.
            */
            var left : Number = Math.floor(layer.position.left / TILE_WIDE);
            var top :  Number = Math.floor(layer.position.top / TILE_HIGH);
            var right : Number = Math.ceil(layer.position.right / TILE_WIDE);
            var bottom : Number = Math.ceil(layer.position.bottom / TILE_HIGH);
            
            const PRELOAD_BOUNDS : int = 1;
            const OUTSIDE_BOUNDS : int = 4;
            
            var rcPreload : Rectangle = new Rectangle((left-PRELOAD_BOUNDS)*TILE_WIDE, (top-PRELOAD_BOUNDS)*TILE_HIGH, ((2*PRELOAD_BOUNDS)+right-left)*TILE_WIDE, ((2*PRELOAD_BOUNDS)+bottom-top)*TILE_HIGH );
            var rcExcess  : Rectangle = new Rectangle((left-OUTSIDE_BOUNDS)*TILE_WIDE, (top-OUTSIDE_BOUNDS)*TILE_HIGH, ((2*OUTSIDE_BOUNDS)+right-left)*TILE_WIDE, ((2*OUTSIDE_BOUNDS)+bottom-top)*TILE_HIGH );
            
            var has : Dictionary = new Dictionary();
            var rid : Array = new Array();
            var idCurr : String;
            var that : TileData;
            var curr : TileData;
            for( idCurr in layer.tiles )
            {
                curr = layer.tiles[idCurr];
                if( !rcExcess.intersects(curr.rect) )
                {   // Outside of rcExcess
                    // Add to eliminate message, and eliminate
                    rid.push(idCurr);
                    curr = layer.tiles[idCurr];
                }
                else if( rcPreload.containsRect(curr.rect) )
                {   // Within preload zone
                    // Build a dictionary of what we actually have
                    has[idCurr] = curr;
                }
                // else ignore it
            }
            
            // Delete distant tiles
            if( 0 != rid.length )
            {
                var message : String = "tile,free,"+id;
                while( 0 != rid.length )
                {
                    idCurr = rid.pop();
                    delete layer.tiles[idCurr];
                    message += ";"+idCurr;
                }
                cb.WSSendText(message);
            }

            // Iterate over tiles, looking for missing/outdated ones
            var row : int;
            var col : int;
            for( row = rcPreload.top; row < rcPreload.bottom && 0 < max; row += TILE_HIGH )
            {
                for( col = rcPreload.left; col < rcPreload.right && 0 < max; col += TILE_WIDE )
                {
                    idCurr = TileID(col,row);
                    curr = tiles[idCurr];
                    if( null != curr )
                    {
                        that = has[idCurr];
                        // If it exists, and they don't have it, or what they have is old...
                        if( null == that || that.tick < curr.tick )
                        {
                            // We need to send a tile.
CONFIG::DEBUG {             debug.Assert(null != curr.data); }
                            layer.tiles[idCurr] = curr;
                            cb.WSSendText("tile,tile,"+idCurr);
                            cb.WSSendText(curr.data);
                            --max;
                        }
                    }
                }
            }

            // Tell client to re-render
            cb.WSSendText("tile,posn,"+layer.position.x+','+layer.position.y+','+layer.position.width+','+layer.position.height+','+layer.scale );
            layer.prev_position = layer.position;
        }
    }
}
