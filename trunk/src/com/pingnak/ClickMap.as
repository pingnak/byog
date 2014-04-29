package com.pingnak
{
    import flash.geom.*;
    import flash.display.*;
    import flash.events.*;
    
    /**
     * This is what we put in a timed map of locations.
     *
     * The server has the current, 'now' state.
     *
     * But the client is displaying 'back then'.  Either a frame behind, or possibly much further in the past.
     *
     * When a user clicks on something he sees, he sees the past.  He is interacting with the past.
     *
     * Worse, by the time the server hears about it, it's the future.  What the user clicked on represents 
     * something from maybe up to 1/3 of a second ago.  The game state on the server has moved on.
     *
     * So what this is, is a record of where something was, back then, so we can infer a reference to an 
     * object, now, if it still exists in the game.
     *
     *
    **/
    public class ClickMap
    {
        protected static const MAX_HISTORY_FRAME : int = 30;

        // AS Arrays is a 'sparse' arrays.  A dictionary keyed with ints.
        protected var aFrames : Array;
        
        // Highest value we have
        protected var max : int;

        // Lowest value we have
        protected var min : int;
        
        public function ClickMap()
        {
            aFrames = new Array();
            max = 0;
            min = 0;
        }
        
        /**
         * Add all of the children of a DisplayObjectContainer, recursively, in Z order
         * @param frame Frame number to add to
         * @param pan Where client is displaying (in game coords)
         * @param scale Size of client, relative to the pan window
         * @param dobjc DisplayObjectContainer
        **/
        public function SnapshotChildren( frame : int, pan : Rectangle, scale:Number, dobjc : DisplayObjectContainer ) : void
        {
            var cframe : ClickMapFrame = aFrames[frame];
            
            if( null == cframe )
            {
                cframe = new ClickMapFrame(pan,scale);
                aFrames[frame] = cframe;
            }
            cframe.AddChildren(dobjc);
            
            // Clean up older children, without changing indexes
            max = Math.max(frame,max);
            min = Math.min(frame,min);
            var minframe : int = max - MAX_HISTORY_FRAME;
            var i : int;
            for( i = min; i < minframe; ++i )
            {
                delete aFrames[i];
            }
            min = minframe;
        }

        /**
         * Fix click coordinates to 'world' coordinated.
         * @param frame Frame number when click happened
         * @param ptio Where click/event happened; gets translated to 'world' coordinates
         * @return false if out of bounds
        **/
        public function FixClick( frame : int, ptio : Point ) : Boolean
        {
            var cframe : ClickMapFrame = aFrames[frame];
            if( null != cframe )
            {
                return cframe.ClickedOn(ptio);
            }
            return null;
        }            
        /**
         * Test if something is clicked.  Return it, if so.
         * @param frame Frame number when click happened
         * @param ptio Where click/event happened; gets translated to 'world' coordinates
         * @return DisplayObject from list, if click landed in a bounding box
        **/
        public function ClickedOn( frame : int, ptio : Point ) : DisplayObject
        {
            var cframe : ClickMapFrame = aFrames[frame];
            if( null != cframe )
            {
trace("ClickedOn", frame, ptio );
                return cframe.ClickedOn(ptio);
            }
            else
            {
CONFIG::DEBUG {
                trace("ClickedOn - No frame:",frame,ptio);
                var ts:String = "";
                var i : int;
                for( i in aFrames )
                    ts += i+" ";
                trace(ts);
}
            }
            return null;
        }
        
    }
    
}
import flash.geom.*;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;

/**
 * Record of where something was. 
 * TODO: Something a little 'better' than bounding boxes
**/
class ClickMapChild
{
    private const origin : Point = new Point(0,0);
    
    /** DisplayObject we're preserving */
    public var dobj : DisplayObject;

    /** Position of DisplayObject, when tested */
    public var pos : Point;
    
    /** Bounding box for it, in stage coordinates */
    public var rBounds : Rectangle;
    
    public function ClickMapChild( dobj : DisplayObject )
    {
        this.dobj = dobj;
        this.rBounds = dobj.getBounds(dobj.parent);
        this.pos = dobj.globalToLocal(dobj.localToGlobal(origin));
    }
    
    public function contains( x:Number, y:Number ) : Boolean
    {
        return this.rBounds.contains(x,y);
    }
}

class ClickMapFrame
{
    public var vFrames : Vector.<ClickMapChild>;
    
    public var pan : Rectangle;
    
    public var scale : Number;

    public function ClickMapFrame( pan : Rectangle, scale : Number )
    {
        vFrames = new Vector.<ClickMapChild>();
        this.pan = pan.clone();
        this.scale = scale;
    }
    
    public function AddChildren( dobjc : DisplayObjectContainer ) : void
    {
        var dobjCurr : DisplayObject;
        var i : int = dobjc.numChildren;
        var bounds : Rectangle;
        while( i-- )
        {
            dobjCurr = dobjc.getChildAt(i);
            bounds = dobjCurr.getBounds(dobjCurr.parent);
            if( pan.intersects(bounds) )
            {
                vFrames.push(new ClickMapChild(dobjCurr));
            }
        }
    }

    public function FixClick( ptio : Point ) : Boolean
    {
        ptio.x = pan.x + (ptio.x * scale);
        ptio.y = pan.y + (ptio.y * scale);
        return pan.contains(ptio.x,ptio.y);
    }
    
    public function ClickedOn( ptio : Point ) : DisplayObject
    {
        // Fix mouse coordinates to match pan window position/scale in use at time of click
        if( !FixClick(ptio) )
            return null;
        var i : int;
        var cmc : ClickMapChild;
        for( i = 0; i < vFrames.length; ++i )
        {
            cmc = vFrames[i];
            if( cmc.rBounds.contains( ptio.x, ptio.y ) )
            {
                return cmc.dobj;
            }
        }
        return null;
    }
};
