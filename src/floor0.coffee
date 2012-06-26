###
#   ogg.js
#   Floor0 Decoding
#
#   Spec for Floor0 decoding:
#   http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-890006
###

OGGDemuxer::decodeFloor0 = ( stream, bitstream ) ->
    order = bitstream.readVorbis(8)
    rate  = bitstream.readVorbis(16)
    barkMapSize = bitstream.readVorbis(16)
    ampBits = bitstream.readVorbis(6)
    ampOffset = bitstream.readVorbis(8)
    bookCount = bitstream.readVorbis(4) + 1
    bookList = []

    if ampBits is 0
        @emit 'error', "Amplitude bits cannot be 0, found #{ampBits}"

    for i in [0...bookCount]
        bookList.push bitstream.readVorbis(8)
        if bookList[i] >= @vorbisCodebookCount
            @emit 'error', "Floor0 book cannot be greater than codebook count"

# VQ vectors of books, used later
### 
    amplitude = bitstream.readVorbis(ampBits)
    if amplitude > 0
        coefficients = []
        bookNumber = bitstream.readVorbis(OGGDemuxer.ilog(bookCount))
        if bookNumber >= @vorbisCodebookCount
            @emit 'error', "Book number #{bookNumber} cannot be greater than codebook count"
        
        last = 0
        tempVector = []
###
