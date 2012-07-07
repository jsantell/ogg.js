###
#   ogg.js
#   Floor0 Decoding
#
#   Spec for Floor0 decoding:
#   http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-890006
###

OGGDemuxer::decodeFloor0 = ( stream, bitstream ) ->
    order = bitstream.readLSB(8)
    rate  = bitstream.readLSB(16)
    barkMapSize = bitstream.readLSB(16)
    ampBits = bitstream.readLSB(6)
    ampOffset = bitstream.readLSB(8)
    bookCount = bitstream.readLSB(4) + 1
    bookList = []

    if ampBits is 0
        @emit 'error', "Amplitude bits cannot be 0, found #{ampBits}"

    for i in [0...bookCount]
        bookList.push bitstream.readLSB(8)
        if bookList[i] >= @vorbisCodebookCount
            @emit 'error', "Floor0 book cannot be greater than codebook count"

# VQ vectors of books, used later
### 
    amplitude = bitstream.readLSB(ampBits)
    if amplitude > 0
        coefficients = []
        bookNumber = bitstream.readLSB(OGGDemuxer.ilog(bookCount))
        if bookNumber >= @vorbisCodebookCount
            @emit 'error', "Book number #{bookNumber} cannot be greater than codebook count"
        
        last = 0
        tempVector = []
###
