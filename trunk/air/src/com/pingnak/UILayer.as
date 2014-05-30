package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Class to encapsulate user interface elements between server and client
    **/
    public class UILayer extends Sprite
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
        
        /** Higher definition UI layer */
        protected var bmUI : BitmapClient;

        /** State to manage this */
        public var smOperation : FSMDObj;

        /** Current UI */
        protected var uiCurr : MovieClip;
        
        /** Alignment for UI */
        protected var alignment : String;
        
        /** Client data to send back to */
        protected var cb : ClientBundle;
        protected var clientWide : uint;
        protected var clientHigh : uint;
        
        public function UILayer( cb : ClientBundle )
        {
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
