###
#   ogg.js
#   Utilities
#
#   Spec for vorbis helper functions:
#   http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-1160009.2 
###

OGGDemuxer.ilog = ( x ) ->
    val = 0
    while x > 0
        val++
        x >>>= 1
    return val

OGGDemuxer.float32Unpack = ( x ) ->
    mantissa = x & 0x1fffff
    exp  = ( x & 0x7fe00000 ) >>> 21
    mantissa *= -1 if x & 0x80000000
    return mantissa * (Math.pow 2, exp - 788)

OGGDemuxer.lookupValue1 = ( entryLength, dimensions ) ->
    x = 1
    x++ while Math.pow(x, dimensions) <= entryLength
    return x-1
