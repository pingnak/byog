
package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Class to move a MovieClip (or sprite) around
     * <br/>
     *
    **/
    public class MCM 
    {
        /** Dispatched whenever it reaches its target */
        public static const ARRIVED : String = "ARRIVED";
        
        /** Dispatched when it reaches its target, OR is stopped */
        public static const STOPPED : String = "STOPPED";

        /** Lookup table for MovieClip motion data */
		private static var dictionary : Dictionary = new Dictionary();
		
		/** Sprite/MovieClip we're moving */
		internal var mc : Sprite;

		/** Motion handler function */
		internal var cbframe : Function;
		
		/** Start position X */
		internal var startX : Number;
		/** Start position Y */
		internal var startY : Number;
		/** End position X */
		internal var targetX : Number;
		/** End position Y */
		internal var targetY : Number;
		
		/** Distance between start and end */
		internal var distance : uint;
		
		/** When motion began */
		internal var startTime : uint;
		
		/** How long motion should take */
		internal var totalTime : uint;
		
		// Working variables, per motion...
		internal var dx : Number;
		internal var dy : Number;
		
		/**
		 * Build the private data for movement 
		 * @param mc Sprite/MovieClip to move
		 * @param tx, ty Where it's going
		 * @param mstime How long it should take, in milliseconds
		**/
		public function MCM(mc:Sprite, tx:Number, ty:Number, mstime : uint)
		{
            MCM.Stop(mc);
		    this.mc = mc;
		    startX = mc.x;
		    startY = mc.y;
		    targetX = tx;
		    targetY = ty;
		    startTime = getTimer();
		    totalTime = mstime;
		    dx = tx - mc.x;
		    dy = ty - mc.y;
		    distance = Math.sqrt((dx*dx)+(dy*dy));
		    dictionary[mc] = this;
		}
		
		/**
		 * Stop motion in progress
		**/
		public static function Stop( mc : Sprite ) : void
		{
		    var mcm : MCM = dictionary[mc] as MCM;
		    if( null != mcm )
		    {
		        mcm.stop();
		    }
		}

		/**
		 * Go from current position to x,y, in 'time' ms
		 * @param mc MovieClip to move
		 * @param x, y Position to go to
		 * @param mstime How long it should take to get there
		**/
		public static function GoTo( mc:Sprite, tx:Number, ty:Number, mstime : uint ) : void
		{
		    MCM.Stop(mc);
		    var mcm : MCM = new MCM(mc,tx,ty,mstime)
		    mcm.cbframe = mcm.Linear;
            mc.addEventListener( Event.ENTER_FRAME, mcm.cbframe );
		}

		/**
		 * Stop, decide whether we reached destination, clean up
		**/
		internal function stop() : void
		{
		    if( this == dictionary[mc] )
		    {
		        delete dictionary[mc];
		    }
            if( targetX == mc.x && targetY == mc.y )
            {
                mc.dispatchEvent( new Event(MCM.ARRIVED) );
            }
            mc.dispatchEvent( new Event(MCM.STOPPED) );
            mc.removeEventListener( Event.ENTER_FRAME, cbframe );
            mc = null;
		}
		
		/**
		 * @private Move along linear path at constant realtime velocity
		**/
		private function Linear( e:Event ) : void
		{
            if( null == mc.stage )
            {   // Poll for on-stage, because it's far simpler, and depth sorting
                stop();
                return;
            }
            
            var age : uint = getTimer() - startTime;
            if( age >= totalTime )
            {
                mc.x = targetX;
                mc.y = targetY;
                stop();
                return;
            }
            // Move along path
            var scale : Number = age / totalTime;
            mc.x = startX + (dx * scale);
            mc.y = startY + (dy * scale);
		        
		}
    }
}

