# Introduction #

So, you have a place with lots of bored people whom you want to keep around, or keep them occupied while they wait for something?

Or perhaps you want to play a game with FRIENDS, rather than strangers and creeps halfway across a continent, or around the world from you?

You could just do like everyone else, and expose whatever computer comes through your doors to the internet.  But this requires an actual internet connection with lots of bandwidth, steep fees to keep it alive and shared, and all kinds of security issues.

What if you could have the crucial things a network connection gives you, without being connected to the internet?

If you have your menu, or announcements online, is there really any need to share it with people in Eastern Europe?

Do you really need a full on web server, on some server farm, who knows where, to give your customers a little entertainment?  Do you really need to share content... with France and China, that needs 24/7 monitoring and security?  And of course, costs money.

Multi-player games need low-latency, low-lag connections.  What shorter ping time than LAN?  Put the server in a box with its own WiFi, and get hacking, or tapping, or whatever the game does.

This is reminiscent of 'LAN Party', except that only one person ever needs the software installed.  Everyone else can run it on a web page, even on fairly wimpy devices.


## Configuration 1: Home ##

This is the simplest.  You run the game server on a good computer, connected to your network, and can play the game with your friends, on whatever devices they bring.  Like the classic 'LAN Party', except only one of you needs the software and a relatively good PC.  Everyone else can bring their own devices (notebooks, netbooks, chromebooks, tablets, phones – anything with a recent enough browser to support HTML5+WebSockets, and a big enough display that they can play on).  Nobody else has to install anything else.  Just log in to your wireless router, connect to your server with a browser, and instantly enter into the game.  Though an Android/iOS/etc. 'dumb client' may be desirable, since they so actively sabotage 'web apps', but would hopefully let a 'dumb client' slide.

Optionally, buy (or obtain, or reuse) a Wifi router just for this.  No need to connect it to the internet.  Directly wire it to a 1000base port on your 'server' computer.  Now everyone can connect to the game and play on an open wifi channel, without revealing your 'real' Wifi password.  Also makes taking the server on the road trivial, and you can play it anywhere, even in a tent in a gods-forsaken desert (assuming you have some power source).  Excellent for military deployment, where internet is not likely to be available, and might not be 'allowed', due to security concerns.  Plug & play.

## Configuration 1a: Game/Embedded Device Controller ##

As a remote control or game controller, or remote administration terminal, the client could readily manage realtime inputs and outputs from a variety of devices.  If it has its own display, you could do just a bit of hacking, and now it can be controlled and monitored by your phone/ipad/computer/Smart TV/etc., through a web browser, on a LAN.  Slash a good chunk of change off your unit cost, with a quick and dirty hack.

## Configuration 2: Business / Coffee Shop / Bar / Waiting Room / etc. ##

One can easily set up a wifi router capable of 'Captive Portal' (it goes to YOUR 'web page' first, no matter what), and you should, even if you're providing 'Just Free Wifi'.  It will identify your business positively, and send users straight to your internal web site, to see specials that only people who CAME IN can see, acknowledge your niceness for providing connectivity, and promising NOT TO do anything evil with your Wifi.  Optionally it can ask for a 'password' that is displayed within your business.  These routers (with built-in captive portal, or capable of being flashed with open source software) are relatively inexpensive, and anyone who's ¼ geek, and can RTFM, can set it up right.  Of course, someone who's geek, through and through could set up a stand-alone router that does this all for them, and provides direct links to your menu, company info, contact, news... and even gaming, if you like.

So, first thing upon joining your wifi network, you can have them automatically see your menu, specials, services, contact info, the 'about' page for the business, employee list, and a list of games and toys to click on.  No groping around on a tablet interface to type, 'http://192.168.0.99:9999'.  The 'server' can also push stuff to a monitor (or 'smart TV' with web capabilities), for the top scores, game status, spectators, advertising.  Play games themed to your business.  No need to provide 'terminals' or 'access pads' at every table.  People's own phones/tablets/notebooks would do the job.  Though you could keep a few 'special' ones on-hand, to loan out after the customer has been positively identified, and swiped a valid card, or otherwise established 'trust', not to run off with it.

A business model of just putting these boxes together and stuffing them under counters and in closets for businesses, to advertise local shopping, services, maps, etc. could easily be built.  Pure ad revenue.  Businesses need buy nothing (unless they want to provide internet, or have a 'real' web site – they'll pay for that, themselves, and plug a cable into the box from their own ISP's MODEM).  Naturally, help them to configure the ISP's router right, if they want this.  It normally doesn't connect to the business' network at all, nor share any internet connection, by default.  Paid subscription to show up in the advertising themselves, get custom pages, visibility on the web (though separate web server), etc.

There's no possibility of a 'leak' of documents through it.  There's no possibility (likelihood) of being hacked from Eastern Europe, or China, or elsewhere, and having your intranet pages vandalized, or worse.  No possibility of a mom handing their kid a tablet, and having pornographic ads pop up in their faces from a 'thought to be safe' web site... through YOUR WIFI.  A nice, safe sandbox.  And it doesn't need to cost a business a penny.  Adjacent businesses can share, too, with routers that support multiple IDs.

These can be physically upgraded (such as with a thumb drive).  This gives you the opportunity to inspect the boxes, make sure they're running right, aren't getting clogged with dust bunnies, and don't have alien things plugged into them, or other kinds of tampering.  It also means that updating is physically secure.  You can't access it all over an anonymous network, from a thousand miles away.  At the same time, anonymous usage logs could be downloaded, as well (how many clicked, on what pages).  Someone just goes door to door, during regular business hours, and does it, or schedules it with the pickier hosts.  Wireless updates over a dedicated VPN, over cellular network are possible, but would also be more expensive.  A 'deal' with a wireless carrier might be struck, to get this 'intermittent' use more cheaply, similar to the way the electric, gas and water companies, and various other embedded systems get network bandwidth for their thousands of things.

So, if you like, the internet can be a 'premium' service, or unavailable, but people who bring their own devices don't have to be shut out from information about your business, estimated waiting time, videos, reading or play.  And for some cases, like coffee shops or pubs, the play could be a draw for customers, in and of its self.

## Configuration 3: Danger Zone ##

It's possible to share your server out on the internet.  You kick open a port on your router's firewall, and point it at the computer that is running the server.  You can get a fixed IP from your ISP, or use 'dyndns' or similar site to point users to your site, from there (some wifi routers have dyndns, or something similar built in - check), or just have your out-of-town friends call you up and ask for the internet ip:port, without unduly advertising your server's existence.  A VPN would be safest.  When you're done playing, you can shut the server down, close the port on the router, and incoming connections on that port will simply be rejected, as usual.

If any of that sounded 'complicated and technical', you probably shouldn't attempt running a game server on the web, at least until you are über-geek familiar with networking.  There are some nasty and surprising liabilities and pitfalls, and if two or three didn't pop into your head, again, you probably shouldn't be hosting a server on the internet.

Naturally, you need a pretty damned good 'upload' speed to run a server over the internet, and that can be pretty expensive with cable or DSL.  Also, long ping times are the bane of the remote player's existence.  They will be consistently gimped.