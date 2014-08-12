package com.pingnak
{
    import flash.events.*;
    import flash.display.*;
    import flash.text.*;
    import flash.geom.*;
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
     *
     * This is more 'stand alone' than the generic Layer from which it derives.  
     * We draw the UI layer separately because it is infrequently refreshed, and 
     * will generally be higher resolution than the game layers are, to display
     * more legible text.
     *
     * We don't synthesize and dispatch events to the native controls, because
     * that won't work.  Implements focus and events internally, to run the UI
     * from more basic elements.
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

        /** UI template */
        protected var uiCurr : MovieClip;
        
        /** Bounding box */
        protected var bounds : Rectangle;
        
        /** State handler */
        protected var fsm : FSM;
        
        /** Set to send fresh frames to app */
        protected var _dirty : int;

        /** Which control has keyboard focus: Only initialized controls get any */
        protected var focus : DisplayObject;
        
        /** Array of potential focus targets, sorted top->bottom, left->right */
        protected var aFocus : Array;
        
        /** Mark animation as dirty */
        public function set dirty(frames:int):void  
        {
CONFIG::DEBUG { debug.Assert( 0 < frames ); }
            _dirty = Math.max(_dirty,frames); 
            fsm.state = "Playing";
        }

        /** Find out how many dirty frames are left */
        public function get dirty():int             { return _dirty; }
        
        /**
         * @param id ID of layer, to give to client
         * @param cb Client bundle to send images back to
         * @param bounds Bounding box
        **/
        public function UILayer( id : String, cb : ClientBundle )
        {
            super( id, cb, WorkerPackData.bPNG | WorkerPackData.bTransparent | WorkerPackData.bDelta | WorkerPackData.bMinimum | WorkerPackData.bBase64 )
            this.cb = cb;
            fsm = new FSM(this);
            Size(bounds);
        }
        
        /**
         * Client window has changed shape/orientation.  Change layout
         * @param bounds Bounding box
        **/
        public function Size( bounds : Rectangle ) : void
        {
            this.bounds = bounds;
            dirty = 1;
        }
        
        /**
         * Show a new UI, or exchange UI
         * @param mc A MovieClip of the UI made in Flash 
         * @param align Where to attach the interface to the game
        **/
        public function Show( mc:MovieClip, align:String="CENTER" ):void
        {
            Hide();
            // Don't design interfaces that animate all the time.  It's expensive
            // to make and send and display high resolution imagery.
            MCE.StopTree(mc);
            uiCurr = mc;
            alignment = align;
            Size(bounds);
        }

        /*
            High level control interface.  
            
            We don't want particularly complex controls or interactions.  
            
            Just enough to get us by.  By keeping this simple, we can let the
            class do the housekeeping, and keep the app code a little cleaner.  
        */
        
        /**
         * Show a new UI, or exchange UI
         * @param mc A MovieClip of the UI made in Flash 
         * @param align Where to attach the interface to the game
        **/
        public function Hide():void
        {
            _dirty = 0;
            fsm.state = FSM.IDLE;
            if( null == uiCurr )
                return;
            aFocus = new Array();
            uiCurr = null;
        }

        /**
         * Set a MovieClip within uiCurr to a given frame/label
         * @return MovieClip 
        **/
        public function SetMovieClip( id : String, label : * ) : MovieClip
        {
            var mc : MovieClip = utils.DObjFindPath( uiCurr, id ) as MovieClip;
CONFIG::DEBUG { debug.Assert( MCE.HasLabel( mc, label ) ); }
            if( null == mc )
                return null;
            mc.gotoAndStop(label);
            return mc;
        }

        /**
         * Play a labeled sequence within MovieClip once, and stop
         * @return MovieClip 
        **/
        public function PlayMovieClip( id : String, label : * ) : MovieClip
        {
            var mc : MovieClip = utils.DObjFindPath( uiCurr, id ) as MovieClip;
CONFIG::DEBUG { debug.Assert( MCE.HasLabel( mc, label ) ); }
            if( null == mc )
                return null;
            MCE.Enable(mc);
            MCE.PlayLabel( mc, label );
            mc.gotoAndStop(label);
            return mc;
        }
        
        /**
         * Configure a button in our UI
         *
         * @param id Search for a DisplayObject of this name, with 'idle,click' frame labels/animations
         * @param cbClick(id) Notification for click; receives name of object (called AFTER click animation played)
         * @return MovieClip button 
        **/
        public function SetButton( id : String, cbClick : Function ) : MovieClip
        {
            var mc : MovieClip = utils.DObjFindPath( uiCurr, id ) as MovieClip;
CONFIG::DEBUG { debug.Assert( MCE.HasLabel( mc, "idle" ) && MCE.HasLabel( mc, "click" ) ); }
            if( null == mc )
                return null;
                
            return mc;
        }

        /**
         * Configure a check button in our UI.  This also implements tabs and 
         * combo boxes.  The difference is only in art/presentation.
         *
         * @param id Search for a DisplayObject of this name, with 'off,on,click' frame labels/animations
         * @param cbClick(id) Notification for click/change; receives name of object
         * @param aRadio Optional array to make this part of a 'radio' button list
         * @return MovieClip button
        **/
        public function SetCheck( id : String, cbClick : Function, aRadio : Array = null ) : MovieClip
        {
            var mc : MovieClip = utils.DObjFindPath( uiCurr, id ) as MovieClip;
CONFIG::DEBUG { debug.Assert( MCE.HasLabel( mc, "off" ) && MCE.HasLabel( mc, "on" ) && MCE.HasLabel( mc, "click" ) ); }
            if( null == mc )
                return null;
                
            return mc;
        }

        /**
         * Get state of check button
         *
         * @param id Search for a DisplayObject of this name, with 'off,on,click' frame labels/animations
         * @return True if 'on', false if 'off'
        **/
        public function GetCheck( id : String ) : Boolean
        {
            var mc : MovieClip = utils.DObjFindPath( uiCurr, id ) as MovieClip;
CONFIG::DEBUG { debug.Assert( null != mc ); }
            return null != mc && "off" != mc.currentLabel; 
        }
        
        /**
         * Set text in an EDITABLE text field
         *
         * Editability is EMULATED on TextField; we can't pass the key events to 
         * it, as if the user pressed them.  This needs to implement the 
         *
         * @param id Search for a DisplayObject of this name
         * @param text Text to set TF to display.  
         * @param cbChanged(id) An optional callback to be notified of     
         * @return TextField, should you wish more control
        **/
        public function SetEdit( id : String, text : String, cbChanged : Function = null ) : TextField
        {
            var tf : TextField = utils.DObjFindPath( uiCurr, id ) as TextField;
CONFIG::DEBUG { debug.Assert( null != tf ); }
            if( null == tf )
                return null;
            tf.text = text;
            return tf; 
        }

        /**
         * Set text in a text field
         * @param id Search for a DisplayObject of this name
         * @param text Text to set TF to display.  May contain simplified html.
         * @return TextField, should you wish more control
        **/
        public function SetText( id : String, text : String ) : TextField
        {
            var tf : TextField = utils.DObjFindPath( uiCurr, id ) as TextField;
CONFIG::DEBUG { debug.Assert( null != tf ); }
            if( null == tf )
                return null;
            tf.htmlText = text;
            return tf; 
        }

        /**
         * Get text from editable TextField
         * @param id Search for a TextField of this name
         * @return TextField.text 
        **/
        public function GetText( id : String ) : String
        {
            var tf : TextField = utils.DObjFindPath( uiCurr, id ) as TextField;
CONFIG::DEBUG { debug.Assert( null != tf ); }
            if( null == tf )
                return "";
            return tf.text; 
        }
        
        /**
         * Receive key codes from client; tab/navigate/dispatch to controls
        **/
        override public function Key( frame : uint, aParams : Array ) : Boolean
        {
            return super.Key(frame, aParams );
        }

        /**
         * Receive 'Mouse click' from client; dispatch to controls
        **/
        override public function Click( frame : int, ptio : Point, shift:Boolean, ctrl:Boolean ) : DisplayObject
        {
            return super.Click(frame, ptio, shift, ctrl );
        }
        
        /**
         * State to generate 
        **/
        public function Playing() : void
        {
            if( 0 >= _dirty-- )
            {
                _dirty = 0;
                fsm.state = FSM.IDLE;
                return;
            }
            
        }
        
    }
}
