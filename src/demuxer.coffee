###
#   ogg.js
#   Ogg Vorbis decoder in JavaScript
#   @jsantell
###

class OGGDemuxer extends Demuxer
    Demuxer.register(OGGDemuxer)

    CAPTURE_PATTERN = 'OggS'
    PAGE_CONT       = 0x01
    PAGE_BOS        = 0x02
    PAGE_EOS        = 0x04
    HEADER_SIG      = 'vorbis'
    HEADER_ID       = 0x01
    HEADER_COMMENTS = 0x03
    HEADER_SETUP    = 0x05
    AUDIO_PACKET    = 0x00
    META_REGEX      = /([^=]*)=([^=]*)/

    @probe = (buffer) ->
        return buffer.peekString(0, 4) is CAPTURE_PATTERN and buffer.peekInt8(4) is 0

    readChunk: ->
        # Ogg Page Header
        if not @pageStarted and @stream.available(27)

            # Check capture pattern
            if @stream.readString(4) isnt CAPTURE_PATTERN
                @emit 'error', 'Invalid Ogg Vorbis file.'

            if @stream.readUInt8() isnt 0
                @emit 'error', 'Invalid Ogg Vorbis version.'

            # Check header type
            @pageHeaderType = @stream.readUInt8()
            if not @started and @pageHeaderType isnt PAGE_BOS
                @emit 'error', 'File must begin with BOS header.'
            if @packetStarted and not @pageHeaderType & PAGE_CONT
                @emit 'error', 'Ogg page headers must denote packet continuation.'
            if @pageHeaderType & PAGE_EOS
                @lastPage = true
            @started = true

            # Read page header
            @position     = @stream.readUInt32()
            @position     = @stream.readUInt32()
            @bitstreamNum = @stream.readUInt32()
            @pageNum      = @stream.readUInt32()
            @checksum     = @stream.readUInt32()
            @numOfSeg     = @stream.readUInt8()
            @segLength    = []

            for i in [0...@numOfSeg]
                @segLength.push @stream.readUInt8()
            @pageStarted = true

        # Vorbis Packet
        while @segLength.length and @stream.available(@segLength[0])
            unless @packetStarted
                @packetType = @stream.readUInt8()
                @packetStarted = true
                @buffer = new BufferList()
                @buffer.push @stream.readSingleBuffer(@segLength[0] - 1)
            else
                @buffer.push @stream.readSingleBuffer(@segLength[0])

            if @segLength[0] < 255
                @parseHeaderId()       if @packetType is HEADER_ID
                @parseHeaderComments() if @packetType is HEADER_COMMENTS
                @parseHeaderSetup()    if @packetType is HEADER_SETUP
                @parseAudioPacket()    if @packetType is AUDIO_PACKET

                @packetStarted = false

            @segLength.shift()
            unless @segLength.length
                @pageStarted = false

    parseHeaderId: ->
        stream = new Stream(@buffer)
        bitstream = new Bitstream(stream)
        @checkHeaderSignature stream

        @vorbisVer  = stream.readUInt32(true)
        @channels   = stream.readUInt8()
        @sampleRate = stream.readUInt32(true)
        @bitRateMax = stream.readUInt32(true)
        @bitRateNom = stream.readUInt32(true)
        @bitRateMin = stream.readUInt32(true)
        @bitRate    = if @bitRateMax is @bitRateMin and @bitRateMax then @bitRateMax else @bitRateNom
        @bitDepth   = @bitRate / @sampleRate / @channels

        @blocksize0 = 1 << bitstream.readVorbis(4)
        @blocksize1 = 1 << bitstream.readVorbis(4)
        framingBit = bitstream.readVorbis(1)

        if @verbisVer
            @emit 'error', "Vorbis version must be 0, found #{@vorbisVer}."
        if @channels < 1
            @emit 'error', "Channels must be > 0, found #{@channels}."
        if @sampleRate < 1
            @emit 'error', "Sample rate must be > 0, found #{@sampleRate}."
        if @blocksize0 > @blocksize1
            @emit 'error', "Blocksize[0] (#{@blocksize0}) must be <= blocksize[1] (#{@blocksize1})."
        if @blocksize1 > 8192
            @emit 'error', "Blocksize[1] must be less than 8192 (#{@blocksize1})."
        unless framingBit
            @emit 'error', 'Framing bit must be non-zero.'

        @format =
            formatID   : 'flac'
            channels   : @channels
            sampleRate : @sampleRate
            bitDepth   : @bitDepth

        @emit 'format', @format

    parseHeaderComments: ->
        stream = new Stream(@buffer)
        bitstream = new Bitstream(stream)
        @checkHeaderSignature stream

        vendorLength = stream.readUInt32(true)
        @vendor = stream.readString(vendorLength)
        metaItems = stream.readUInt32(true)
        metadata = {}

        for i in [0...metaItems]
            itemLength = stream.readUInt32(true)
            itemValue = stream.readString(itemLength)
            itemValue = itemValue.match META_REGEX
            if itemValue and itemValue.length
                metadata[ itemValue[1] ] = itemValue[2]

        unless bitstream.readVorbis(1)
            @emit 'error', 'Framing bit must be non-zero.'

        @emit 'metadata', metadata

    parseHeaderSetup: ->
        stream = new Stream(@buffer)
        bitstream = new Bitstream(stream)
        @checkHeaderSignature stream

        # Codebooks
        @vorbisCodebookCount = bitstream.readVorbis(8) + 1
        @vorbisCodebooks = []
        for i in [0...@vorbisCodebookCount]
            @vorbisCodebooks.push @decodeCodebook( stream, bitstream )

        # Time domain transforms (placeholder)
        @vorbisTimeCount = bitstream.readVorbis(6) + 1
        for i in [0...@vorbisTimeCount]
            if bitstream.readVorbis(16) isnt 0
                @emit 'error', 'All time domain transforms must be 0'

        # Floors
        @vorbisFloorTypes  = []
        @vorbisFloorConfig = []
        @vorbisFloorCount  = bitstream.readVorbis(6) + 1
        for i in [0...@vorbisFloorCount]
            @vorbisFloorTypes[i] = bitstream.readVorbis(16)
            if @vorbisFloorTypes[i] is 0
                @vorbisFloorConfig.push @decodeFloor0( stream, bitstream )
            else if @vorbisFloorTypes[i] is 1
                @vorbisFloorConfig.push @decodeFloor1( stream, bitstream )
            else
                @emit 'error', "Vorbis floor types must be 0 or 1, found #{@vorbisFloorTypes[i]}"

    parseAudioPacket: ->
        stream = new Stream(@buffer)
        temp = stream.readBuffer stream.remainingBytes()
        console.log temp
        @emit 'data', temp

    checkHeaderSignature: ( stream ) ->
        if stream.readString(6) isnt HEADER_SIG
            @emit 'error', 'Invalid packet header in file.'

