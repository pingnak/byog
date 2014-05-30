package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.utils.*;

    /**
     * Class to encapsulate user interface elements between server and client
    **/
    public class UIButton
    {
        /** Button frame ID: in idle state */
        public const WAITING   : String = "idle";

        /** Button frame ID: was tapped, and is playing activation */
        public const CLICKED   : String = "clicked";

        /** Check box is checked */
        public const CHECKED   : String = "checked";

        /** Check box is unchecked */
        public const UNCHECKED : String = "unchecked";

        /** If this frame is present in the button, use it to show disabled, else alpha = 0.5 */
        public const DISABLED  : String = "disabled";
        
        /** UI this is attached to */
        protected var ui : UILayer;
        
        /** MovieClip this is attached to */
        protected var mc : MovieClip;
        
        /** Callback for activation */
        protected var onClick : uint;
        
        /** Optional sound effect to play when this is tapped */
        protected var fxID : String;
        
        /** Optional keyboard shortcut for this (accessible by UILayer) */
        internal var keyCode : uint;
        
        /** List of other check boxes to uncheck, if this is checked */
        protected var aRadio = null;

        
        
        /**
         * Set up button
         * @param ui UILayer this is part of
         * @param mc MovieClip that acts out activity
         * @param onClick Function to call when this is activated
         * @param fxID Optional sound effect to trigger on activation
         * @param keyCode Optional Keyboard shortcut key code
        **/
        public function UIButton( ui : UILayer, mc : MovieClip, onClick : Function, fxID:String = "", keyCode : uint = 0 )
        {
            this.ui = ui;
            this.mc = mc;
            this.onClick = onClick;
            this.keyCode = keyCode;
            
            // Build map of frames, decide if it's a check box or activation button; set up accordingly 
            
        }
        
        /**
         * Add a checkbox button to a radio button array
        **/
        public function IsRadio(a:Array):void
        {
        }

        public function Enable(bEnabled:Boolean = true):void
        {
        }

        public function Disable():void
        {
            Enable(false);
        }

        public function 
        
    }
}
