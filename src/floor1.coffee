###
#   ogg.js
#   Floor1 Decoding
#
#   Spec for Floor1 decoding:
#   http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-950007
###

OGGDemuxer::decodeFloor1 = ( stream, bitstream ) ->
    partitionCount = bitstream.readVorbis(5)
    maxClass = -1
    partitionList = []
    classDim  = []
    classSubs = []
    classBook = []
    classSubBook = []

    for i in [0...partitionCount]
        partitionList.push bitstream.readVorbis(4)
        maxClass = partitionList[i] if partitionList[i] > maxClass

    for i in [0..maxClass]
        classDim.push bitstream.readVorbis(3) + 1
        classSubs.push bitstream.readVorbis(2)
        if classSubs[i] isnt 0
            classBook[i] = bitstream.readVorbis(8)
        for j in [0...1<<classSubs[i]]
            (classSubBook[i] ?= [])[j] = bitstream.readVorbis(8) - 1

    mult = bitstream.readVorbis(2) + 1
    rangebits = bitstream.readVorbis(4)
    count = 0
    floor1XList = [0, 1 << rangebits]
    for i in [0...partitionCount]
        count += classDim[partitionList[i]]
        for j in [0...count]
            floor1XList[j+2] = bitstream.readVorbis(rangebits)
