Implement a simple tool to turn a vector swf into a layered PSD.

FLA must export a swf containing just the animation needed, on the stage.   
We expect a single frame, with the various parts labeled for external 
animation.  Potentially, I may prompt for exported symbols within the swf,
but there's no way to 'get' a list of symbols.

Unfortunately, since Adobe despises their Flash users, the jsfl scripting has
nothing useful, like the Photoshop extendscript has, to read/write PSD layers.

Recurse through DisplayList, and make the various named DisplayObjects into 
named layers, at correct layouts and depths.  

Unnamed components may optionally be composited together into a single bitmap.

Scale up/down and render individual parts to an appropriate resolution for
eventual target platform.

Make this scriptable, so it can be repeated after minor changes to the artwork.

Frames and animations?  Probably not.  Keeping the parts separate and getting
something to animate within Unity is my goal here, and working out what's 
being reused (or not), frame by frame gets messy.

* Notes

http://blog.teleranek.org

http://durej.com/?p=128

http://forum.unity3d.com/threads/29327-Flash-To-Unity
