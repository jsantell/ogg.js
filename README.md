ogg.js: An Ogg Vorbis decoder in JavaScript
=====================================

## still in heavy development! not yet working!

ogg.js uses the [Aurora](https://github.com/ofmlabs/aurora.js) audio framework by ofmlabs to facilitate decoding and playback.

## Building

Currently, the [import](https://github.com/devongovett/import) module is used to build ogg.js.  You can run the development server by first installing `import` with npm, and then running it like this:

    sudo npm install import -g
    import ogg.js -p 3030

You can also build a static version like this:

    import ogg.js build.js

Once it is running on port 3030, you can open test.html and select an ogg file from your system to play back.

## Todo
The remaining items still need to be developed
* Header Floors Decoding
* Header Residue Decoding
* Header Mapping Decoding
* Header Modes Decoding
* Audio Packet Window Decoding
* Audio Packet Floor Curve Decoding
* Audio Packet Residue Decoding
* Audio Packet Output
