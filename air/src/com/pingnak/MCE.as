
package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.Dictionary;

    /**
     * Class to notify us when a MovieClip play head hits points of interest
     * <br/>
     * Two implementations:
     *
     * One depends on MovieClip.addFrameScript, which could 'disappear' someday.
     *
     * One does not, but will poll the MovieClip each frame to detect change,
     * even when a MovieClip is not animating, since there's no way to ask.
     *
    **/
    public class MCE extends Event
    {
        /**
         * Playback has started on 'label'
        **/
        public static const LABEL_FIRST : String = "label_first";

        /**
         * Last frame of a frame label has been reached
        **/
        public static const LABEL_LAST : String = "label_last";
        
        /**
         * First frame of clip
        **/
        public static const FIRST : String = "first";

        /**
         * Last frame of clip
        **/
        public static const LAST : String = "last";
        

        public function MCE( type : String )
        {
            super(type);
        }
        
CONFIG::DIKEIN
{
        /**
         * Scan labels in a MovieClip, add frame callbacks to trigger events
         * Something Flash should do, really.
         * 
         * You must add Event handlers, yourself.  Call this only if you intend to do so.
         *
         * Caution: Code in the timeline, on the same frames will be overridden.
         *
         * @param mc Clip to create callbacks on - 
         * @return Same mc you passed in 
        **/
        public static function Enable( mc : MovieClip ) : MovieClip
        {
            var lastFrame : int = mc.totalFrames;
            var labels:Array = mc.currentLabels;
            if( 0 == labels.length )
            {   // Make a label just for the whole clip
                AddLabel(1,lastFrame)
            }
            else
            {   // Run through labels backwards, so we have last fram from previous
                while( 0 != labels.length ) 
                {
                    var currlabel:FrameLabel = labels.pop();
                    AddLabel( currlabel.frame, lastFrame );
                    lastFrame = currlabel.frame-1;
                }
            }

            // Function to set up the callbacks
            function AddLabel(first:int,last:int):void
            {
                if( first == last )
                {
                    mc.addFrameScript( first-1, EventOneFrame );
                }
                else
                {
                    if( 1 == first )
                    {   // First frame generates two events
                        mc.addFrameScript( first-1,EventFIRST );
                    }
                    else
                    {
                        mc.addFrameScript( first-1,EventLABEL_FIRST );
                    }
                    if( mc.totalFrames == last )
                    {   // Last frame generates two events
                        mc.addFrameScript( last-1,EventLAST );
                    }
                    else
                    {
                        mc.addFrameScript( last-1,EventLABEL_LAST );
                    }
                }
            }
            /** Handler for first frame and its label */
            function EventFIRST() : void
            {
                mc.dispatchEvent( new MCE(MCE.FIRST) );
                if( null != mc.currentLabel )
                    mc.dispatchEvent( new MCE(MCE.LABEL_FIRST) );
            }
            /** Handler for first frame of a labeled run of frames */
            function EventLABEL_FIRST() : void
            {
                mc.dispatchEvent( new MCE(MCE.LABEL_FIRST) );
            }
            /** Handler for last frame of clip */
            function EventLAST() : void
            {
                if( null != mc.currentLabel )
                    mc.dispatchEvent( new MCE(MCE.LABEL_LAST) );
                mc.dispatchEvent( new MCE(MCE.LAST) );
            }
            /** Handler for last frame of a labeled run of frames */
            function EventLABEL_LAST() : void
            {
                mc.dispatchEvent( new MCE(MCE.LABEL_LAST) );
            }
            /** Handler for single frame clip */
            function EventOneFrame() : void
            {
                if( mc.currentFrame == 1 )
                {
                    mc.dispatchEvent( new MCE(MCE.FIRST) );
                }
                if( null != mc.currentLabel )
                {
                    mc.dispatchEvent( new MCE(MCE.LABEL_FIRST) );
                    mc.dispatchEvent( new MCE(MCE.LABEL_LAST) );
                }
                if( mc.currentFrame == mc.totalFrames )
                {
                    mc.dispatchEvent( new MCE(MCE.LAST) );
                }
            }
            return mc;
        }

        /**
         * Pull the plug on event callbacks
         * Does NOT clean up leaky events.
         *
         * @param mc Clip to remove callbacks from 
         * @return Same mc you passed in 
        **/
        public static function Disable( mc : MovieClip ) : MovieClip
        {
            mc.stop();
            var frame : int;
            for( frame = 0; frame < mc.totalFrames; ++frame )
            {
                mc.addFrameScript( frame, null );
            }
            return mc;
        }
}

CONFIG::DIKEOUT
{
        /** Keep track of details, so we can pull the plug on these */
        private static var triggerLUT : Dictionary = new Dictionary();

        /**
         * Scan labels in a MovieClip, add frame callbacks to magically trigger the MovieClip events that should be PART OF FLASH
         * 
         * You must add Event handlers, yourself.  Calling this means you intend to do so
         *
         * The version with addFrameScript could be Enable and forgotten, but 
         * for this one, you should 'Disable' as soon as possible, or you will
         * spend a lot of time polling an idle MovieClip.
         * 
         * @param mc Clip to create callbacks on - 
         * @return Same mc you passed in 
        **/
        public static function Enable( mc : MovieClip ) : MovieClip
        {
            var lastFrame : int = mc.totalFrames;
            var labels:Array = mc.currentLabels;
            var triggers : Array = new Array();
            while( 0 != labels.length ) 
            {
                var currlabel:FrameLabel = labels.pop();
                if( currlabel.frame == lastFrame )
                {
                    triggers[currlabel.frame] = "both";
                }
                else
                {
                    triggers[lastFrame] = LABEL_LAST;
                    triggers[currlabel.frame] = LABEL_FIRST;
                }
                lastFrame = currlabel.frame-1;
            }
            triggers[0] = -1;
            mc.addEventListener( Event.ENTER_FRAME, mcPermanentCallback );
            triggerLUT[mc] = triggers;

            return mc;
        }

        // This function will exist for as long as the MovieClip exists
        // Poll for change, generate events
        private static function mcPermanentCallback(e:Event):void
        {
            var mc : MovieClip = e.target as MovieClip;
            var triggers : Array = triggerLUT[mc];
            if( null == mc.stage || null == triggers )
            {   // Poll for mc removal - so sorting DisplayObjects won't cause it to stop working
                Disable(mc);
                return;
            }
            if( mc.currentFrame != triggers[0] )
            {
                var which : * = triggers[mc.currentFrame];
                if( 1 == mc.currentFrame )
                {
                    mc.dispatchEvent( new MCE(FIRST) );
                }
                if( undefined != which )
                {
                    if( "both" == which )
                    {
                        mc.dispatchEvent( new MCE(LABEL_FIRST) );
                        mc.dispatchEvent( new MCE(LABEL_LAST) );
                    }
                    else
                    {
                        mc.dispatchEvent( new MCE(which) );
                    }
                }
                if( mc.totalFrames == mc.currentFrame )
                {
                    mc.dispatchEvent( new MCE(LAST) );
                }
                triggers[0] = mc.currentFrame;
            }
        }
        
        /**
         * Pull the plug on event callbacks
         * Does NOT clean up leaky events.
         *
         * @param mc Clip to remove callbacks from 
         * @return Same mc you passed in 
        **/
        public static function Disable( mc : MovieClip ) : MovieClip
        {
            mc.stop();
            mc.removeEventListener( Event.ENTER_FRAME, mcPermanentCallback );
            delete triggerLUT[mc];
            return mc;
        }
}

        /**
         * Callback to stop a played clip
        **/
        public static function StopIt(e:Event):void
        {
            var mc : MovieClip = e.target as MovieClip;
            mc.stop();
            mc.removeEventListener( MCE.LABEL_LAST, StopIt );
        }


        /**
         * Loop a clip
        **/
        public static function LoopIt(e:Event):void
        {
            var mc : MovieClip = e.target as MovieClip;
            mc.gotoAndPlay(mc.currentLabel);
        }
        
        /**
         * Play a label, stop at the end, clean up
         * @param mc MovieClip to play a portion of, and stop
         * @param label Which portion
        **/
        public static function PlayLabel( mc : MovieClip, label : String ) : void
        {
            mc.gotoAndPlay(label);
            mc.addEventListener( MCE.LABEL_LAST, StopIt );
        }
        
        /**
         * Loop a label endlessly
         * @param mc MovieClip to play a portion of, and stop
         * @param label Which portion
         * Note - To break the loop, you would need to play some other segment of the clip, 
         * but the next time you played the looped label, it would still loop.
        **/
        public static function LoopLabel( mc : MovieClip, label : String ) : void
        {
            mc.gotoAndPlay(label);
            mc.addEventListener( MCE.LABEL_LAST, LoopIt );
        }

        /**
         * Check if a MovieClip has a label.
         * @param mc to test
         * @param label Label of frame to test
        **/
        public static function HasLabel( mc : MovieClip, label : * ) : Boolean 
        {
CONFIG::DEBUG { debug.Assert( label is Number || label is String ); }
            if( null == mc )
            {   // Null, or not movieclip
                return false;
            }
            if( label is Number )
            {   // Frame is in range
                return int(label) >= 1 && int(label) <= mc.totalFrames;
            }
            var obj : FrameLabel;
            for each( obj in mc.currentLabels )
            {
                if( obj.name == label )
                    return true;
            }
            return false;
        }
        
        /**
         * Find out how many frames are in a labeled set of frames
         * @param mc to test
         * @param label Label of frame series to test
         * @return Count of frames, or 0 if label doesn't exist
        **/
        public static function NumFrames( mc : MovieClip, label : String ) : int 
        {
            if( null == mc )
            {   // Null, or not movieclip
                return 0;
            }
            var obj : FrameLabel;
            var i : int;
            for( i = 0; i < mc.currentLabels.length; ++i )
            {
                obj = mc.currentLabels[i];
                if( obj.name == label )
                {
                    if( i < mc.currentLabels.length - 1 )
                    {   // From label, to next label
                        return mc.currentLabels[i+1].frame - obj.frame;
                    }
                    else
                    {   // From label, to end
                        return 1 + mc.totalFrames - obj.frame;
                    }
                }
            }
            return 0;
        }


        /**
         * Find MovieClips in a DisplayObject, and stop them all, and do some rudimentary cleanups.
         * A MovieClip in flash is very wasteful.  Every little MovieClip within
         * a MovieClip is initially playing when it is created.  It's a lot of 
         * housekeeping.  This will clean up
         * @param dobj DisplayObject that may contain MovieClips, to stop
        **/
        public static function StopTree( dobj : DisplayObject ) : void
        {
            utils.DObjBreadthFirst( dobj, Stop );
            function Stop(dobj:DisplayObject):DisplayObject
            {
                if( dobj is MovieClip )
                {
                    MCE.Disable(dobj as MovieClip)
                    MCM.Stop(dobj as MovieClip);
                }
            }
        }

        /**
         * Find MovieClips in a DisplayObject, and play them all.
         * @param dobj DisplayObject that may contain MovieClips, to play
         * @param startFrame Optional start frame/label to play from
        **/
        public static function PlayTree( dobj : DisplayObject, startFrame : *= 1 ) : void
        {
            utils.DObjBreadthFirst( dobj, Start );
            function Start(dobj:DisplayObject):DisplayObject
            {
                if( dobj is MovieClip )
                {
CONFIG::DEBUG {     // In debug mode, seeking a movieclip to undefined frame throws an exception                   
                    if( MCE.HasLabel(dobj as MovieClip,startFrame) )
                        (dobj as MovieClip).gotoAndPlay(startFrame);
                    else
                        (dobj as MovieClip).gotoAndPlay(1);
}
CONFIG::RELEASE {   // In release mode, the above test is done for us
                    (dobj as MovieClip).gotoAndPlay(startFrame);
}

                }
            }
        }
    }
}

