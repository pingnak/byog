
package com.worker
{
    /**
     * This is a bit of a detour, so I'm not going to spend much time without
     * any external demand for it.  
     *
     * Basically, animated things are 'modeled', and this attempts to break down
     * exported symbols within an existing swf into a 2D, layered model, and
     * maintain the relative positions and origins of its components, already 
     * painstakingly set within Flash or Photoshop.
     *
     * Somehow, the folks at Unity don't appear to understand the importance for
     * artists to lay things out visually, in tools familiar to them, and appear 
     * to believe there is zero labor involved with repetitively picking imagery   
     * apart by hand, to spoon feed it to a much-too-simple import, that ends
     * up making a puzzle, only to be re-assembled in their GUI with even more
     * labor, usually by someone else, because the ones who are really good at
     * making the prettiest art are usually borderline computer illiterate.
     *
     * I will define an XML script to control the tasks, rather than a GUI, as
     * this is more the 'build it' end of things than the 'draw it', and 
     * relationships between shared content and imported symbols don't make it 
     * through when someone who 'needs a GUI' uses one.  Also, this would be
     * miserably repetitive and error-prone to poke check marks and navigate
     * paths, rather than simply give it a to-do list, and let it do its 
     * business.
     * 
     * This tool will do a few well defined tasks:
     *
     * SWF To PSD
     *
     * Run through a MovieClip, recursively, find every unique reference to 
     * 'something', and render those 'Somethings' into a layered PSD file, 
     * with all of the parts in their correct relative positions, if not their
     * correct orientations (you may have to mirror/rotate/flip things in the 
     * unity animator, because there aren't enough parameters to pass to the 
     * SpriteMetaData object, to control how things like this work.
     *
     * The PSD file will have a control layer, named 'origin'.  A quick scan from
     * top->bottom, left->right for non-transparent finds a pixel, that position 
     * becomes the origin.  If you define multiple origin layers, only the first
     * one discovered will be used.  Something like an arrow pointing up/left 
     * would work as the origin specifier, but it's just looking for that set 
     * pixel.
     * 
     * SWF To Atlas
     *
     * Do the same as above, but spit all of the layers out into a big, fat
     * png file, with some contextual krazy glue for a Unity AssetPostprocessor
     * script to pick over.  Since Unity does its own sprite packing, I don't 
     * need to concentrate on packing them together, here.  Only getting them
     * into unity, and identifying WHERE THEY BELONG and/or where the grab point 
     * is.
     *
     * PSD To Atlas
     *
     * Take a layered PSD, similar to what this makes, and spit out the same 
     * Atlas data and image.
    **/
    class Swf2Psd
    {
    }
}
