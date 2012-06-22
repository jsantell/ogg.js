###
 ogg.js - Ogg Vorbis decoder in JavaScript
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
                return @emit 'error', 'Invalid Ogg Vorbis file.'

            if @stream.readUInt8() isnt 0
                return @emit 'error', 'Invalid Ogg Vorbis version.'

            # Check header type
            @pageHeaderType = @stream.readUInt8()
            if not @started and @pageHeaderType isnt PAGE_BOS
                return @emit 'error', 'File must begin with BOS header.'
            if @packedStarted and not @pageHeaderType & PAGE_CONT
                    return @emit 'error', 'Ogg page headers must denote packet continuation.'
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
        while @stream.available @segLength[0]
            unless @packetStarted
                @packetType = @stream.readInt8()
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
        stream = new Stream( @buffer )
        @checkHeaderSignature stream

        stream.advance(4) # vorbis version
        @channels   = stream.readUInt8()
        @sampleRate = stream.readUInt32(true)
        @bitRateMax = stream.readInt32(true)
        @bitRateNom = stream.readInt32(true)
        @bitRateMin = stream.readInt32(true)
        @bitRate    = if @bitRateMax is @bitRateMin and @bitRateMax then @bitRateMax else @bitRateNom
        @bitDepth   = @bitRate / @sampleRate / @channels

        # Block size needs to be cut into 4 bit chunks and checked
        # that blocksize[0] <= blocksize[1]
        console.log stream.readUInt8(), 'blocksize0,1'
        # Not sure what framing flag is used for
        console.log stream.readUInt8(), 'flag'

        @format =
            formatID   :'flac'
            channels   : @channels
            sampleRate : @sampleRate
            bitDepth   : @bitDepth
        console.log @format

        @emit 'format', @format

    parseHeaderComments: ->
        stream = new Stream(@buffer)
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

        console.log stream.readUInt8(), 'framing bit'

        console.log metadata
        @emit 'metadata', metadata

    # TODO
    parseHeaderSetup: ->
        stream = new Stream(@buffer)
        @checkHeaderSignature stream

        @vorbisCodebookCount = stream.readUInt8()
        bitstream = new Bitstream(stream)
        @vorbisTimeCount = bitstream.read(6) + 1

    parseAudioPacket: ->
        stream = new Stream(@buffer)
        temp = stream.readBuffer stream.remainingBytes()
        console.log temp
        @emit 'data', temp

    checkHeaderSignature: ( stream ) ->
        if stream.readString(6) isnt HEADER_SIG
            return @emit 'error', 'Invalid packet header in file.'
