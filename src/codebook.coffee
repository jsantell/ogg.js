OGGDemuxer::decodeCodebook = ( stream, bitstream ) ->
    codebook = {}
    if (syncPattern = bitstream.readV(24)) isnt 0x564342
        @emit 'error', "Invalid codebook sync pattern: #{syncPattern}."
    console.log(syncPattern)

    codebook.dimensions  = bitstream.readV(16)
    codebook.entryCount  = bitstream.readV(24)
    codebook.entries     = []


    # Whether codewords are ordered or unordered
    # Unordered way more common
    unless bitstream.readV(1)
        # Can there be unused entries?
        codebook.sparse = bitstream.readV(1)
        for i in [0...codebook.entryCount]
            if codebook.sparse
                # if flag is set, read stream, otherwise unused
                if bitstream.readV(1)
                    (codebook.entries[i] = {}).length = bitstream.readV(5) + 1
                else
                    (codebook.entries[i] = {}).length = null
            else
                (codebook.entries[i] = {}).length = bitstream.readV(5) + 1
    # Ordered codewords
    # Uncommon/unused?
    else
        currentLength = bitstream.readV(5) + 1
        i = 0
        while i < codebook.entryCount
            number =  bitstream.readV(OGGDemuxer.ilog(codebook.entryCount - i))
            for j in [i..i+number-1]
                (codebook.entries[j] = {}).length = currentLength
                i++
                currentLength++
                if i > codebook.entryCount
                    @emit 'error', "More codeword lengths (#{i}) than codebook entries (#{codebook.entryCount})."


    # Skip lookup decoding if type 0
    if ( codebook.lookupType = bitstream.readV(4) )
        codebook.minValue      = OGGDemuxer.float32Unpack bitstream.readV(32)
        codebook.deltaValue    = OGGDemuxer.float32Unpack bitstream.readV(32)
        codebook.valueBits     = bitstream.readV(4) + 1
        codebook.seq           = bitstream.readV(1)
        codebook.multiplicands = []

        if codebook.lookupType is 1
            codebook.quantValue = OGGDemuxer.lookupValue1 codebook.entryCount, codebook.dimensions
        # Uncommon/unused?
        else if codebook.lookupType is 2
            codebook.quantValue = codebook.entryCount * codebook.dimensions
        else
            @emit 'error', "Codebook lookup type #{codebook.lookupType} is reserved and not supported"

        for i in [0...codebook.quantValue]
            codebook.multiplicands.push bitstream.readV(codebook.valueBits)

###
    usedCodewords = []
    for entry in codebook.entries
        continue if entry.length is null # skip unused entries
        codeword = entry.length
        codeword++ while codeword in usedCodewords
        usedCodewords.push codeword
        entry.codeword = codeword
###

