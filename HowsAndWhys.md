# Hows and Whys #

Some of the code decisions may seem mystifying from an initial review.  This document attempts to justify them in some small way.

## What is this? ##
This grew from a burnt-out question of “HTML5 sucks... but what could I do with it, if I had to?”  If you ever tried to make an HTML5/WebKit game of any complexity work on more than one device, you would have had problems.  Lots of them.  And new ones keep 'happening', all the time.  Mainly because no two browsers work the same as each other, and even the same browser works differently, over minor version releases.  If you implement with 'web technology' on the client, anything that is not trivial will break.  All the time.  A standard ain't a standard if you need 'middleware' to work with it, and even that middleware doesn't keep up... which can be a BIG problem when people are demanding a fix, NOW, but the fix to the problem is buried in that middleware, and a (stable) update for that hasn't been released.

I decided to see if I could implement a 'dumb terminal' to run games.

As it turns out, I can make games run like this.  With caveats.

Mostly, this is a technical test/demonstration of what can be done for 'any modern browser' with a local, or ISP based server connection, and is not a recommendation for something on the wider internet, with what is in many cases awful ping times and downright awful bandwidth available to its users.  I would only recommend running this on a LAN/'WiFi', or a dedicated app served by a local ISP, and certainly not a cellular network, as this would clean out your bandwidth limits pretty quickly, and the cellular radio usually needs a lot more power than the WiFi radio, so you'd be holding a brick and looking for an outlet, in no time.  With WiFi, it definitely works for hours, on battery.
This demonstrates running a multiplayer game on 'dumb terminals' implemented in web browsers that support some recent version of Canvas, WebSockets/XMLHttpRequest, and WebKit Audio/Web Audio.  Much of the client's code is actually test code and duplicate/fallback versions of the client's functionality, for browser compatibility going back a few versions, before we can't rely on much of anything to work at all, ever.
What you should see are some little colored airplanes (controlled by you and others), some brainless NPC bugs that you can click/tap on, and a familiar (if you're a gamer) background map that I have no right to use or redistribute.  It should run on most phones and tablets and netbooks and computers with a reasonably up-to-date browser, without installing anything, and without much of a start-up time to get into the game.  We do this by rendering the active portion of the game on the server, and letting the client display it, and sending user events back to the server.

The background is composed of pre-compressed tiles, spoon fed to the client with instructions for what to keep, what to discard, and where/how to scale+render.  The airplanes and bugs are a series of transparent PNG files, encoded in realtime, in their own Worker threads.

It's not really a game, it's a torture test.

Though this can run on a notebook with perhaps a dozen clients, on a 'good' wireless network (according to distribution of 2.4GHz vs. 5GHz capable clients), with a much better server, and better router, it should support dozens.  Enough for any home or small venue.  With less challenging interfaces, with infrequent updates (trivia, bingo, keno, casino games, maps), probably up to a hundred simultaneous users, according to what kind of hardware and network you can assemble, and connect users to.
BYOD for gaming/contests.  No need to install anything.

When you run it, for best results, the computer that's running the server should have a wired connection to the wireless router.  It's the big choke point.

Basically, you can make a multiplayer game, even relatively 'massively' so, with about the same effort as writing a 'split screen' game, and support downright basic hardware to play on.  Use people's phones/tablets/etc. as individualized display and input devices (game controllers).  What you see here is compatible with a 'Realtime Strategy' game, or a multiplayer RPG, or 'Gauntlet', or 'Diablo', or various other panning, multiplayer type games, side-scrollers, platform, etc.  A real '3D' rendered perspective would require a real video CODEC, but there are lots of 2.5D and raycasting things that could be made to work, with a little perseverance, and clever masking of the sprite layer.  The deeper problem of approximating a 3D POV is that the more '3D' it looks, the more people will actually complain that it's not like 'Skyrim', or whatever game du-jour.  Certainly 3D rendered sprites could be incorporated into a '2D' environment, to simplify modeling complex, animated things.  That's all implementation details on the server side.  On the client side, it's just a stream of images.

## Why a 'Dumb Terminal'? ##

The client is kept simple.  Simple is better in many ways.  There is little dependence on how a web client (or its 'hardware acceleration' and drivers) respond to various attributes and primitives required to render the game.  No need to properly define and license distributable fonts and other resources.  There is less to break, as the underlying so-called 'web standards' evolve out from under it.  There is less to make hacker-proof.  There is less to port, should we implement 'native' clients.  Battery operated devices spend more time listening to the radio receiver, and not rendering primitives and running script.  It also means that there is much less to review in the protocol, far fewer assets on the client to steal, less client code to 'trust', and generally more secure overall.  (Plus, someone in China won't hijack the client and make a web server to run it, short of reproducing the entire game.)  There isn't a lot you can 'hack' on the client that a few weeks of QA, trying to find the holes won't plug.  It's completely under the server's control what is displayed, and how it reacts to user inputs.  On the server side, you only have to make one model of the game 'work'.  Not the 'server' version, and then the 'client' version.  The server side can display what the clients are doing, for its self, if desired.  The server side can apply effects, 3D render, and do all of the things that you can only 'sort of' make work on Canvas, on some browsers... on some OS versions... on some platforms... on some hardware... sometimes.
Also, arbitrary complexity.  In an RPG game, with characters that can be dressed, or many kinds of 'things' to encounter, the traditional model would require you to GET all of the parts of them, and composite and animate them on the client.  Or have them stored on the client (big install, easy to hijack).   This way, you can have the Neko mage in the purple cloak of Kawaii, wielding a Staff of Colorfulness, a little green man in a Hawaii shirt with a chaingun, and all kinds of combinations of items/wearables/creatures, without any extra client-side work over making them all the same.  Since the server can be 'special', and have higher runtime requirements than any reasonable client requirement, all of that junk can always be in RAM, even in texture memory on the GPU, and never swapped out.  MUCH simpler.  So the same game will work on an Android phone with 512MB of RAM, as a Tablet with 1GB of RAM, as a desktop machine dragged into range and plugged in, with gigabytes of RAM.

## Why So Blurry? ##

I send a lower resolution image than the client (except for some phones with really low resolution), mainly for crummy tablet/phone performance, compounded by relatively crummy AIR PNG compression performance, on higher resolution images.  On some browsers, the scaling looks worse than others, and always looks worse, the bigger you blow it up.  'Retro' pixelated effects are certainly possible.  This is adjustable, but more CPU and more bandwidth, for more pixels, and all of that.  There is little to no control over how browsers 'scale' imagery.  This is like a snowflake on a Titanic-sinking iceberg, compared to all of the problems in HTML5 Canvas and various flavors of browsers.  There's certainly more tinkering to do, and possibilities of allowing 'real desktop' clients to work in 'HD', however detection of what has that kind of capability is difficult, from a web based client, and even harder from the server, and was beyond the scope of my initial effort.  According to whether this is home or venue or ISP based, that 'HD' may become a significant liability, if everyone brings a notebook with a big 'retina' display, to play.

Things that could easily simplify/multiply the compression would be writing a native eight bit color indexed render engine, limiting the art to a more standardized palette, and sending only 8 bit PNGs (or GIFs, if we're dealing with color indexed art).

Another modest improvement would be eliminating some of the standard 'chunks' off the PNG files we send constantly, and tacking them on, on the client side.  That way, we could send just the IDAT chunks, and paste them into a PNG template that matches the format.

Moving the base64 step to the client would obviously save 25% off network bandwidth, but you'll probably have to slow down the frame rate for less capable devices.

## Typing in that IP:Port... ##

Well, you need a name server, and preferably a 'captive portal' capable router, with a welcome page that would link or redirect you to the game(s).

## Glitches in Certain Browsers ##

There is only so much I can do to make this 'work right'.  If, (like uniquely for IE9), the browser can't decode and render PNGs from Base64 reliably, I elect not to make a special case to try to 'fix it'.  If the browser is this broken, no amount of 'fixing' on my end will ever cure it, and certainly the 'fix' would be even more harrowing, with a more complex game client.  If there are problems that YOU are personally seeing with YOUR browser on YOUR device, that nobody else has... then use a web browser (or device, if the browser is locked down by the OS, for planned obsolescence) that doesn't suck.  I can't make it my personal problem to support ALL of the brokenness for ALL of the broken browsers, ever.  There's too much, even for a 'simple' client.  I can only hope that as development progresses, the 'mainstream' browsers become more capable and reliable, and the standards gel into something less ephemeral.

## PNG images ##

This is the lightest of the available formats that all web browsers recognize (more or less), and decode natively.  Even so, PNG is a heavy file format, with a lot of time-consuming bloat to it, like calculating CRCs for data blocks.  It would be nice if we always had multiple high speed hardware MP4 encoders, for multiple realtime streams, but we don't have that in most computers, certainly not the necessary decoders in all web clients, and definitely not cheaply, if you want to equip them with such.  Nor do we have access to hardware assisted JPEG compression, to approximate an MJPEG CODEC.  At least, not from Adobe AIR's runtime.

## Text I/O and PNGs ##

The big problem with sending images to a web browser is that the only channel other than a URL to let it download it for its self, is to set 'src' with the data in a Base64 format.  Sending this is cumbersome, but not as slow and cumbersome on some 'mobile' browsers would be, sending it in binary, then writing code to make a new copy to convert it to Base64, to pass it to Image.src, and then have it de-convert it, making another copy again, before decoding and making yet another copy in RGB format, to use.  The additional network bandwidth versus an extra copy/translate for each frame.  While I could readily write a far more efficient CODEC to transfer and render this data, it would have to be written in script on both ends of the connection for this prototype.  Super-bad.

There is some context based message handling that gives details of the image, and then the image, in separate messages.  This is again to prevent extra steps of replicating/moving lots of data for no reason.  This is 'safe' because I have one communication socket open, being fed from one thread, so it doesn't insert things into the stream, out of order.

## Setting things to NULL or '' ##

Some Javascript implementations in browsers clean up after themselves properly.  Some (like Amazon's Silk browser) leak everything, with a vengeance.  Not only where messages are received, but in nested/closure functions that never, ever clean up, so the data never, ever gets dereferenced, and after a few minutes, the device runs out of RAM.  Explicit clean-ups at least slow the bleeding on the worst of the pigs.
Implementing a Web Server

This seems 'already invented', yet implementing a basic HTTP+WebSocket server is trivial, but configuring an existing 'general purpose' web server, and adding such functionality to it is DEFINITELY NOT.  It's far easier to start with a rendering/gaming engine, like AIR or Unity, or various other, solutions, and then tack a simple 'web server' onto it, optimized for my purposes, than to try to make it work beneath a web server that never made any assumptions compatible with my use, and tries to be everything to every possible application, and match functionality to other, even more inefficient scripting APIs for every combinations of script+server... except what I need.

## Adobe AIR ##

Well, why not?  It's a 'free', cross-platform 2D sprite+animation engine and runtime.  It's good enough for this prototype.  Native C code on the server side could certainly increase the cycles available for this process, but would not really add very many users, as the bottleneck quickly becomes the network, its self.  It was just convenient to whack together a prototype, and test it, coming off a few years of AS3 programming.  A C version, as a native extension to a game engine would take a couple of months, give or take, now that I know 'it works'.

## Server Side Packaging ##

The server maintains a web page and a few odds and ends on its side, including whatever resources it ultimately sends to the client.  Most of the resources would never be accessible to a web client, except as composited and served by the game.  Currently, all is bundled into the AIR package.

The client is minimally obfuscated at runtime and syntax-checked, mainly to reduce its size.  Assets are loaded into RAM, and cached, to keep the server from becoming disk bound.  It's safe to make such an assumption because gigabytes of RAM are cheap, and I KNOW what I will be serving.  At startup, excess white space, about as much comments as code, and various runtime options are compiled in/out for debug versus release mode, so I don't have to 'compile' the script to see it work in a debugger, versus deploy it.  Parameters for the client are mixed in when the page is loaded, so the load time for a client is just one unit.

While I could pre-cache the game sounds and other assets with the client, I don't.  It would make it a bit smoother to do so, but in a large game where there could be a lot of random speech and other events, this wouldn't help very much, except for exceedingly common effects.

## The Sound: Why So Laggy?  Why absent? ##

The only kind of sound that is nearly-consistently 'realtime' playable is WebKit audio, and that is not supported on every browser.  Even with, it's much snappier on some browsers than others.  On Opera, the last hold-out for MP3 support, you won't hear anything, because this only serves MP3.  On older versions of various browsers, or IE (no WebKit), you may be hearing Web Audio (one sample, played through the web page loading/caching... if ever cached) versus WebKit audio API.  Needless to say, the 'Web Audio' can be awfully slow to begin playing, especially on browsers that refuse to cache audio, and make the server stream it from scratch... every... single... time.

## The Web Client Is Procedural / Isn't (your personal favorite development pattern) ##

Bite me.  Seriously, it's written to be simple and clear, all in one file, not to conform to your latest fads.