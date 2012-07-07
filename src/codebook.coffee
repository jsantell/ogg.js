###
#   ogg.js
#   Codebook decoding
#
#   Spec for decoding vorbis codebooks:
#   http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-470003
###

OGGDemuxer::decodeCodebook = ( stream, bitstream ) ->
    codebook = {}
    if (syncPattern = bitstream.readLSB(24)) isnt 0x564342
        @emit 'error', "Invalid codebook sync pattern: #{syncPattern}."
    console.log(syncPattern)

    codebook.dimensions  = bitstream.readLSB(16)
    codebook.entryCount  = bitstream.readLSB(24)
    codebook.entries     = []


    # Whether codewords are ordered or unordered
    # Unordered way more common
    unless bitstream.readLSB(1)
        # Can there be unused entries?
        codebook.sparse = bitstream.readLSB(1)
        for i in [0...codebook.entryCount]
            if codebook.sparse
                # if flag is set, read stream, otherwise unused
                if bitstream.readLSB(1)
                    (codebook.entries[i] = {}).length = bitstream.readLSB(5) + 1
                else
                    (codebook.entries[i] = {}).length = null
            else
                (codebook.entries[i] = {}).length = bitstream.readLSB(5) + 1
    # Ordered codewords
    # Uncommon/unused?
    else
        currentLength = bitstream.readLSB(5) + 1
        i = 0
        while i < codebook.entryCount
            number =  bitstream.readLSB(OGGDemuxer.ilog(codebook.entryCount - i))
            for j in [i..i+number-1]
                (codebook.entries[j] = {}).length = currentLength
            i += number
            currentLength++
            if i > codebook.entryCount
                @emit 'error', "More codeword lengths (#{i}) than codebook entries (#{codebook.entryCount})."


    # Skip lookup decoding if type 0
    if ( codebook.lookupType = bitstream.readLSB(4) )
        codebook.minValue      = OGGDemuxer.float32Unpack bitstream.readLSB(32)
        codebook.deltaValue    = OGGDemuxer.float32Unpack bitstream.readLSB(32)
        codebook.valueBits     = bitstream.readLSB(4) + 1
        codebook.seq           = bitstream.readLSB(1)
        codebook.multiplicands = []

        if codebook.lookupType is 1
            codebook.quantValue = OGGDemuxer.lookupValue1 codebook.entryCount, codebook.dimensions
        # Uncommon/unused?
        else if codebook.lookupType is 2
            codebook.quantValue = codebook.entryCount * codebook.dimensions
        else
            @emit 'error', "Codebook lookup type #{codebook.lookupType} is reserved and not supported"

        for i in [0...codebook.quantValue]
            codebook.multiplicands.push bitstream.readLSB(codebook.valueBits)

###
    usedCodewords = []
    for entry in codebook.entries
        continue if entry.length is null # skip unused entries
        codeword = entry.length
        codeword++ while codeword in usedCodewords
        usedCodewords.push codeword
        entry.codeword = codeword
###

