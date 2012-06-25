###
#   ogg.js
#   Aurora.js Bitstream extension for Vorbis Packets
#
#   Spec (http://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-360002)
###

Bitstream.vorbisMask = [
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

Bitstream::readVorbis = ( bits ) ->
    modBits = bits + @bitPosition
    a  = (@stream.peekUInt8()  & 0xFF) >>> @bitPosition
    a |= (@stream.peekUInt8(1) & 0xFF) << (8 - @bitPosition)  if modBits > 8
    a |= (@stream.peekUInt8(2) & 0xFF) << (16 - @bitPosition) if modBits > 16
    a |= (@stream.peekUInt8(3) & 0xFF) << (24 - @bitPosition) if modBits > 24
    a |= (@stream.peekUInt8(4) & 0xFF) << (32 - @bitPosition) if modBits > 32
    @advance bits
    return a & Bitstream.vorbisMask[bits]

