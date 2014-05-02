
package com.pingnak
{
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;

    /**
     * Encapsulate information about tiles
    **/
    public class TileLayer 
    {
        /** List of tiles the client should have, now */
        public var tiles  : Dictionary;

        /** Current position, to map with tiles */
        public var position : Rectangle;

        /** Current scaling value */
        public var scale : Number;

        public var prev_position : Rectangle;
        
        public function TileLayer(position:Rectangle,scale:Number)
        {
            this.position = position.clone();
            this.prev_position = new Rectangle();
            this.scale = scale;
            this.tiles = new Dictionary();
        }
        
    }
}

