
package com.pingnak
{
    import flash.geom.*;
    
    /**
     * Encapsulate information about a tile
    **/
    public class TileData 
    {
        public var cache: TileCache; // What this belongs to
        public var tick : Number; // When this was created/changed
        public var id   : String; // When this was created
        public var data : String; // Pre-compressed Base64 encoded png, ready for browser client
        public var rect : Rectangle; // Where it is
        public function TileData(cache:TileCache, tick:Number, id:String, data:String)
        {
            this.cache= cache;
            this.tick = tick;
            this.id = id;
            this.data = data;
            var posn : Point = TileCache.TilePos(id);
            this.rect = new Rectangle(posn.x,posn.y, cache.TILE_WIDE, cache.TILE_HIGH );
        }
    }
}

