Following text was pulled from Ctrl-Alt-Rees (https://ctrl-alt-rees.com/2020-11-26-pixelmusic-3000-modern-atari-video-music-clone-parallax.html) who sourced and built the original example from where these sources originate.
---
---
The Pixelmusic 3000 Atari Video Music Clone
Here I’m collecting some files that were presumed lost to time to preserve the sadly now defunct Uncommon Projects’ Pixelmusic 3000, an open source, GPL licensed clone of the Atari Video Music based on a Parallax Propellor microcontroller.

This project was featured on Make Magazine’s website back in 2012, but all of the links are now dead thanks to Uncommon Projects’ demise and that makes me sad. 😔

Here’s Make Magazine’s official PDF of the project, as generated back in 2012.

My plan is to build one of these once I have all of the info together.

Here’s a video of the device in action:


Bill Of Materials (BOM)
22-gauge solid hookup wire (1) Various colors
Ribbon cable (1) Any width
DC power jack to PCB adapter (1) That fits wall-wart plug, Digi-Key #CP-202A-ND
6V 300mA DC power supply (1) ‘Wall wart’
Prop Plug programming connector (1) Parallax #32201
Slide switch (1)
Rubber feet (4) (1)
Wood-grain contact paper (1) from a local hardware store
Serpac A-21 enclosure, black (1) Jameco #373333
10kΩ trimpot variable resistor (1) Aka potentiometer
Perf board (1) RadioShack #276-150
40-pin IC socket (1)
Microchip MCP3208 analog-to-digital converter (ADC) (1)
24LC 256 256K serial EEPRO M memory (1)
Propeller 40-pin microcontroller (1) Parallax #P8X32A-D40
Mini-to-RCA A/V cable (1)
LM2937 3.3V voltage regulator (1)
5MHz crystal (1)
Circuit board headers: 3-pin and 4-pin (1)
Red LED (1)
Resistors: 270Ω (2), 560Ω, 1.1kΩ, 4.7kΩ (2), and 10kΩ (1)
Capacitors: 0.1μF and 22μF (1)
Stereo mini (3.5mm) cable (1)
Other Bits & Bobs
You’ll need the PropellorIDE to be able to flash the code.
You’ll also need a Prop Plug!
(OK, there may be other ways to do this, I have zero experience with the Propellor but this is the recommended method as per the original instructions)

Files
Schematic
Parallax .spin file (original MAKE version)
Parallax .spin file (later Uncommon Projects version with comments, some tweaks etc.)
For either of the above, you’ll also need Graphics.spin, MCP3208.spin, and TV.spin
Version converted for the Propellor Demoboard (archived from here)
More info as I track it down. Files were recovered using The Wayback Machine from links I found online.