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
            bitstream = new Bitstream(@stream)

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
        bitstream = new Bitstream(stream)
        @checkHeaderSignature stream

        @vorbisVer  = stream.readUInt32()
        @channels   = stream.readUInt8()
        @sampleRate = stream.readUInt32(true)
        @bitRateMax = stream.readInt32(true)
        @bitRateNom = stream.readInt32(true)
        @bitRateMin = stream.readInt32(true)
        @bitRate    = if @bitRateMax is @bitRateMin and @bitRateMax then @bitRateMax else @bitRateNom
        @bitDepth   = @bitRate / @sampleRate / @channels

        # blocksize = stream.readUInt8()
        @blocksize0 = 1 << bitstream.readV(4)
        @blocksize1 = 1 << bitstream.readV(4)
        framingBit = bitstream.readV(1)

        if @verbisVer
            @emit 'error', "Vorbis version must be 0, found #{@vorbisV}."
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

        console.log stream.readUInt8() & 1, 'framing bit'

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

    decodeCodebook: ( stream ) ->
        codebook = {}
        bitstream = new Bitstream( stream )
        if (syncPattern = bitstream.readV(24)) isnt 0x564342
            @emit 'error', "Invalid codebook sync pattern: #{syncPattern}."
        console.log(syncPattern)
        codebook.dimensions  = bitstream.readV(16)
        codebook.entryLength = bitstream.readV(24)
        codebook.ordered     = bitstream.readV(1)
        codebook.entries   = []

        # Codeword length
        unless codebook.ordered
            codebook.sparse = bitstream.readV(1)
            for i in [0...codebook.entryLength]
                if codebook.sparse
                    # if flag is set, read stream, otherwise unused
                    if bitstream.readV(1)
                        (codebook.entries[i] = {}).length = bitstream.readV(5) + 1
                    else
                        (codebook.entries[i] = {}).length = null
                else
                    (codebook.entries[i] = {}).length = bitstream.readV(5) + 1
        else
            currentEntry = 0
            while currentEntry < codebook.entryLength
                currentLength = bitstream.readV(5) + 1
                number =  bistream.readV(ilog(codebook.entryLength - currentEntry))
                for i in [currentEntry..currentEntry+number-1]
                    codebook.entries[i].length = currentLength
                    currentEntry += number
                    currentLength++
                    if currentEntry > codebook.entryLength
                        @emit 'error', "More codeword lengths (#{currentEntry}) than codebook entries (#{codebook.entryLength})."

        # Skip lookup decoding if type 0
        if ( codebook.lookupType = bitstream.readV(4) ) 
            codebook.minValue      = float32Unpack bitstream.readV(32)
            codebook.deltaValue    = float32Unpack bitstream.readV(32)
            codebook.valueBits     = bitstream.readV(4) + 1
            codebook.seq           = bitstream.readV(1)
            codebook.multiplicands = []

            if codebook.lookupType is 1
                codebook.lookupValue = lookupValue1 codebook.entryLength, codebook.dimensions
            else if codebook.lookupType is 2
                codebook.lookupValue = codebook.entryLength * codebook.dimensions
            else
                @emit 'error', "Codebook lookup type #{codebook.lookupType} is reserved and not supported"

            for i in [0...codebook.lookUpValue]
                codebook.multiplicands.push bitstream.readV(codebook.valueBits)

        # Assigning entries
        usedCodewords = []
        for entry in codebook.entries
            continue if entry.length is null # skip unused entries
            codeword = entry.length
            codeword++ while codeword in usedCodewords
            entry.codeword = codeword

        last = 0
        indexDivisor = 1
        @valueVectors = []
        for i in [0...codebook.dimensions - 1]
            multOffset = 0

    Bitstream::mask = [
        0x00000000, 0x00000001, 0x00000003, 0x00000007,
        0x0000000f, 0x0000001f, 0x0000003f, 0x0000007f,
        0x000000ff, 0x000001ff, 0x000003ff, 0x000007ff,
        0x00000fff, 0x00001fff, 0x00003fff, 0x00007fff,
        0x0000ffff, 0x0001ffff, 0x0003ffff, 0x0007ffff,
        0x000fffff, 0x001fffff, 0x003fffff, 0x007fffff,
        0x00ffffff, 0x01ffffff, 0x03ffffff, 0x07ffffff,
        0x0fffffff, 0x1fffffff, 0x3fffffff, 0x7fffffff,
        0xffffffff
    ]
    Bitstream::readV = ( bits ) ->
        mask = @mask[bits]
        aBits = bits + @bitPosition
        a  = (@stream.peekUInt8()  & 0xFF) >>> @bitPosition
        a |= (@stream.peekUInt8(1) & 0xFF) << (8 - @bitPosition)  if aBits > 8
        a |= (@stream.peekUInt8(2) & 0xFF) << (16 - @bitPosition) if aBits > 16
        a |= (@stream.peekUInt8(3) & 0xFF) << (24 - @bitPosition) if aBits > 24
        a |= (@stream.peekUInt8(4) & 0xFF) << (32 - @bitPosition) if aBits > 32
        @advance bits
        a &= mask
        return a

    checkHeaderSignature: ( stream ) ->
        @emit 'error', 'Invalid packet header in file.' if stream.readString(6) isnt HEADER_SIG

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

