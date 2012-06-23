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
        stream = new Stream(@buffer)
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

        @vorbisCodebookCount  = stream.readUInt8() + 1
        @vorbisCodebookConfig = []
        for i in [0...@vorbisCodebookCount]
            @vorbisCodebookConfig.push @decodeCodebook( stream )

        bitstream = new Bitstream(stream)
        @vorbisTimeCount = bitstream.read(6) + 1

    parseAudioPacket: ->
        stream = new Stream(@buffer)
        temp = stream.readBuffer stream.remainingBytes()
        console.log temp
        @emit 'data', temp

    checkHeaderSignature: ( stream ) ->
        @emit 'error', 'Invalid packet header in file.' if stream.readString(6) isnt HEADER_SIG

    decodeCodebook: ( stream ) ->
        codebook = {}
        if (syncPattern = stream.readUInt24(true)) isnt 0x564342
            @emit 'error', "Invalid codebook sync pattern: #{syncPattern}."
        codebook.dimensions  = stream.readUInt16(true)
        codebook.entryLength = stream.readUInt24(true)
        codebook.ordered     = stream.readUInt8()
        codebook.sparse      = !!(codebook.ordered & 0x02)
        codebook.ordered     = !!(codebook.ordered & 0x01)
        codebook.entries   = []

        # Codeword length
        bitstream = new Bitstream( stream )
        unless codebook.ordered
            for i in [0...codebook.entryLength]
                if codebook.sparse
                    # if flag is set, read stream, otherwise unused
                    if bitstream.readOne()
                        (codebook.entries[i] = {}).length = bitstream.read(5)
                    else
                        (codebook.entries[i] = {}).length = null
                else
                    (codebook.entries[i] = {}).length = bitstream.read(5) + 1
        else
            currentEntry = 0
            while currentEntry < codebook.entryLength
                currentLength = bitstream.read(5) + 1
                number =  bistream.read ilog(codebook.entryLength - currentEntry)
                for i in [currentEntry..currentEntry+number-1]
                    codebook.entries[i].length = currentLength
                    currentEntry += number
                    currentLength++
                    if currentEntry > codebook.entryLength
                        @emit 'error', "More codeword lengths (#{currentEntry}) than codebook entries (#{codebook.entryLength})."

        codebook.lookupType    = bitstream.read(4)
        codebook.minValue      = float32Unpack stream.readUInt32(true)
        codebook.deltaValue    = float32Unpack stream.readUInt32(true)
        codebook.valueBits     = bitstream.read(4) + 1
        codebook.seq           = bitstream.readOne()
        codebook.multiplicands = []

        if codebook.lookupType is 1
            codebook.lookupValue = lookupValue1 codebook.entryLength, codebook.dimensions
        else if codebook.lookupType is 2
            codebook.lookupValue = codebook.entryLength * codebook.dimensions
        else
            @emit 'error', "Codebook lookup type #{codebook.lookupType} is reserved and not supported"

        for i in [0...codebook.lookUpValue]
            codebook.multiplicands.push bitstream.read(codebook.valueBits)

        # Assigning entries
        usedCodewords = []
        for entry in codebook.entries
            continue if entry.length is null # skip unused entries
            codeword = entry.length
            codeword++ while codeword in usedCodewords
            entry.codeword = codeword


    ilog = ( x ) ->
        val = 0
        while x > 0
            val++
            x >>>= 1
        val

    float32Unpack = ( x ) ->
        mantissa = x & 0x1fffff
        sign = x & 0x80000000
        exp  = ( x & 0x7fe00000 ) >>> 21
        mantissa *= -1 if x
        mantissa * (Math.pow 2, exp - 788)

    lookupValue1 = ( entryLength, dimensions ) ->
        x = 1
        x++ while Math.pow(x, dimensions) <= entryLength
        x

