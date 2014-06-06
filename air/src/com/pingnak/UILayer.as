package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

/*    
    TO DO:
    
    Implement on top of Layer class, using notes from this prototype.
    
    Build plane picking test case, and other nik-naks.
    
    Fixup client so layers are less 'complicated'?
    
    Probably implement to work without subclassing UILayer, since this is 
    sort of a heavy-weight class.  Do most of the mundane work here, and 
    generate/synthesize events to drive state, per user.

    Work out partial div layer coverage, for huds and other such things, to 
    reduce some of the work the client does (theoretically, anyways)
    
    Unlike sprite layer, this should be 1:1 resolution (up to a limit - no 
    need to screw with 'retina' resolutions) and infrequently refreshed.  
    
    Do 'diff' packing, since most UIs are solid and only have some parts 
    refreshed.  This will exercise code in Worker/BitmapClient that is untested,
    so bugs are likely to turn up.

    More competent mouse/touch/keyboard tracking.
    
    Add show/hide client triggers to Layer class.

    I'm probably not going to make a 'generic' client handling mode; the client
    we serve should know about how the server works, and vice-versa, so no need
    for databases and tables on client side, to handle cases that we don't use.
    
    Fix long poll client capabilities!  It's broken, for now, until I finish
    tinkering with render handlers.  Think about how to make it less bothersome,
    even though this will probably be the last major refactoring of render layers
    that keep breaking it.
    
    Trigger Zoopy/Fadey effects on client side?  This sort of animation would be
    simpler+smoother if triggered from server, and acted out by client.  Most 
    likely a 'snapshot' layer to get dead/previous UI, and 'new one' (or none),
    and apply some quick, stock scale+alpha effects to it.
        PopIn: Pop up UI instantly
        FadeIn: Fade up, on top of game
        CrossFade: Exchange UIs (new shown, 'old' fades out - only suitable for 'full screen' UI)
        FadeOut: Remove UI with fancy fade
        PopOut: Remove UI instantly
        
*/    
    /**
     * Class to encapsulate user interface elements between server and client
    **/
    public class UILayer extends Layer
    {
        /*
         * Where to align interface
         *
         * Since we have no idea about size and shape of window, we need to 
         * specify a position anchored relative to the window,
         *
         * It also means an interface should be designed to 'fit'.  Laying out 
         * the UI horizontally will be a pain when the user flips a phone
         * vertically.  We can overcome some things with scaling, but some
         * cases will yield controls that are too small for fat fingers to 
         * 'touch', without some careful thought.
         *
         * Since this is 'multiplayer', there is no 'pause'.  All of these UIs
         * will sit on top of the 'live' game, though the game (for this player)
         * may not have started, yet.  While a full-screen UI is up is a good 
         * time to, say, download the tile map around the player's current 
         * position.
         */
         
        /** Middle of screen */
        public static const CENTER      : String = "CENTER";
        /** Top of screen, centered horizontally */
        public static const TOP         : String = "TOP";
        /** Bottom of screen, centered horizontally */
        public static const BOTTOM      : String = "BOTTOM";
        /** Left edge of screen, centered vertically */
        public static const LEFT        : String = "LEFT";
        /** Right edge of screen, centered vertically */
        public static const RIGHT       : String = "RIGHT";
        /** Pinned to top+left corner */
        public static const TOPLEFT     : String = "TOPLEFT";
        /** Pinned to top+right corner */
        public static const TOPRIGHT    : String = "TOPRIGHT";
        /** Pinned to bottom+left corner */
        public static const BOTTOMLEFT  : String = "BOTTOMLEFT";
        /** Pinned to bottom+right corner */
        public static const BOTTOMRIGHT : String = "BOTTOMRIGHT";
        
        
        /** Alignment for UI */
        protected var alignment : String;
        
        
        public function UILayer( id : String, cb : ClientBundle )
        {
            super( id, cb, WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bDelta | WorkerPackData.bMinimum | WorkerPackData.bBase64 )
            this.cb = cb;
            smOperation = new FSMDObj(this);
        }
        
        /**
         * Show a new UI, or exchange UI
         * @param mc A MovieClip of the UI made in Flash 
         * @param align Where to attach the interface to the game
        **/
        public function Show( mc:MovieClip, align:String="CENTER" ):void
        {
            uiCurr = mc;
            alignment = align;
            mc.stop();
        }

        /**
         * Client window shape/orientation update
         * @param clientWidth   Size of client window
         * @param clientHeight  Size of client window
         * @param align Optionally changle alignment
        **/
        public function SetPos( clientWidth:uint, clientHeight:uint, align:String=null ):void
        {
            if( null != align )
                alignment = align;
        }
        
        /**
         * Client touch/click input
         * @param mx Mouse/tap x position
         * @param my Mouse/tap y position
         * @return true if handled
        **/
        public function Click( mx : Number, my : Number ) : Boolean
        {
        }

        /**
         * Client key input
         * @param code Key code
         * @param my Mouse/tap y position
         * @return true if handled
        **/
        public function Key( code : uint ) : Boolean
        {
        }
        
        /**
         * Clean up UI
        **/
        public function Hide():void
        {
            mc = null;
            uiCurr = null;
            // Tell client to hide
        }
        
        /**
         * Render an update, then send to client
        **/
        protected function Refresh():void
        {
        }

    }
}
