# What you will need... #

To make and embed art and animations, some version of Flash.  It's possible to do this with mxmlc's 'Embed', too.  You'll need Flash CS5.5 or later to open the project fla file.

You'll need Apache Ant

https://ant.apache.org/

You'll need Adobe AIR SDK (and compiler) 4.0 or later.

https://helpx.adobe.com/air/kb/archived-air-sdk-version.html

To install the AIR package, you'll need the AIR runtime.

https://get.adobe.com/air/

# Running #

Once installed, launch the AIR application.  Give it a port higher than 1024.  Run it.  Your OS may generate a warning about the firewall.  Allow it to listen to that port, or nobody will be able to connect.

Enter the IP:Port (e.g. http://192.168.0.50:7777).  Most browsers don't need you to type the 'http://' portion, but some do.

If you're going to have more than a very few connections, you should plug the computer that's running the server into a wired connection to the router.  This will save lots of wireless bandwidth for the clients.

# Building and Testing #

Once you have ant and the AIR SDK installed, and in your path, just type 'ant -p' for a list of build targets.

The default 'all' target would normally make all of the sub-projects, but for now there's only the one.  This will package the app.

The 'run' and 'runtrace' targets will run the release and debug version of the project, respectively, without generating an AIR package.

You may also use the adt tool directly, to 'run' your server, without packaging it or installing it within your own production environment.  Look to the buildapp.xml for the parameters you need, or 'ant -V run', and watch the output.  Handier for a server that you won't be distributing.

The 'rundebug' target will build and launch the app, so it can be debugged with Adobe's fdb.  You need to run fdb first, in another shell, and type 'run'.  That will set it up to wait for your app's connection to it.

The first time you build it, it will generate a self-signed certificate to build the app.  Don't commit this.  That's YOUR certificate, and not to be shared.

# Troubleshooting the installer #

A few bugs I've noticed in the AIR installer.  First off, if your certificate doesn't match the previous certificate, you'll have to uninstall the previous version of the game, to install one signed by you.  AIR doesn't give you any messages about WHY.  That's just what you'll have to do.

Also, I've noticed that it's sensitive to WHERE the AIR package was installed from, previously.  The AIR installer likes to hang if I download it into another folder, and attempt to install it, but launching the same package from the same folder it was previously installed from... works.

# What's There #

The 'build.xml' file is the main ant build script.  The build.properties contains common properties for all sub-projects.  The 'buildapp.xml' file is the actual build script that is applied to sub-projects.

The 'src' folder contains the source code.  The 'src/BugTest' contains the specific BugTest source.  The 'pingnak' folder is common code.  The 'worker' folder is for the AS3 Worker class that does the image compression in a thread.

The 'BugTest.fla' is a Flash CS5.5 file that contains the art and animations that are embedded in the game as a swf, in src/BugTest/Resource.swf.

The 'artistry' folder is just where I do the various transformations on things, to make some of the parts of the game.  The 'tesselate.sh' script uses ImageMagick to build the tile map for the background, and a couple of other tools to try to shrink the png files a little better.

The 'BugTest' folder contains the various resources that are packaged with AIR, and ultimately the AIR file, its self.  The 'client' folder contains content that can be served to the client.  The 'server' folder contains private server configurations.  The build.properties file defines some things about BugTest, for buildapp.xml to use.

# Linux #

Shortly after starting into this project, I discovered that Adobe ended Linux support after AIR 2.6.  Another huge shotgun blast to the foot on their part, but they've never been known to be smart about anything.  The Unity version certainly WILL run under Linux, as that will be part of the Steam OS support.