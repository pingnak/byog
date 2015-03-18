# AIR #

## BugTest ##

This is the build folder for the Bug Test app.

  * client This is where files served to the web client go.  XML/HTML files are filtered to insert commands at runtime.  In a release mode build, excess white space is also removed.

  * server This is where to dump server-side resources that are not (directly) given to the client.  Mainly the server.xml, which has a bunch of preferences for how the server works.  Most notably 'ARENA\_SIZE', which configures how big a window goes around the airplanes, and eventually how much resolution makes it back to the clients.

## src ##

### com/BugTest ###

Source files for the Bug test app.

  * BugTest.swc comes from BugTest.fla.

  * Main.as is an implementation of the Server class, which runs the overall 'game', such as it is.

  * GameClient.as implements a notional connection from a game client, and manages their airplane, and their inputs.

### com/pingnak ###

This is common, reusable code.

  * Server.as and ClientConnection.as implement the HTTP server.  Server.as derives from applet.as, which just buries some housekeeping where I don't have to scroll over it.

  * ClientBundle.as implements a higher level client, that tries to keep track of which connections are associated with a session.  This is harder than it should be.

  * BitmapClient.as, WorkerPackData,as communicate with the worker thread, to get renders packed.

  * TileCache.as, TileLayer.as, TileData.as keep track of what the user is seeing, and what the client should be keeping around.

  * Pool.as, MCPool.as, ByteArrayPool.as implement various kinds of memory pools, to reuse some allocation, rather than let Flash's 'mark & sweep' handling misplace and leak it.

  * MCE.as, MCM.as implement primitive MovieClip playback events and motion controls.

  * debug.as, utils.as are mainly dumping grounds for various related functions.

### com/worker ###

AS3 threading is sort of hackish, and very quirky.  This is the project for the 'thread' that does the image packing.

  * WorketPackData.as Definitions for some of the packaging this thread does

  * BitmapClient.as The 'main thread' interface to the worker thread.  This is where coordination is done for invoking the threads.

# Unity #

This is still a stub.

This will be the Unity implementation of the same beast, so I'll have a version of the SERVER that can run under Linux (SteamOS), and various other platforms that Adobe has spurned in their arrogance and apathy.  A tiny little UK company can support all of these platforms, but not a huge multinational, like Adobe, because it's 'too expensive' for Adobe to do anything but make buggy tools, like Flash, and fail by the numbers.