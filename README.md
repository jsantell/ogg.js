ogg.js: An Ogg Vorbis decoder in JavaScript
=====================================

**under heavy development**

ogg.js uses the [Aurora](https://github.com/ofmlabs/aurora.js) audio framework by ofmlabs to facilitate decoding and playback.

## Building

Currently, the [import](https://github.com/devongovett/import) module is used to build ogg.js.  You can run the development server by first installing `import` with npm, and then running it like this:

    sudo npm install import -g
    import ogg.js -p 3030

You can also build a static version like this:

    import ogg.js build.js

Once it is running on port 3030, you can open test.html and select a flac file from your system to play back.
