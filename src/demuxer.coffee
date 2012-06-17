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
    if not @readPageHeader and @stream.available(27)
      if @stream.readString(4) isnt CAPTURE_PATTERN
        return @emit 'error', 'Invalid Ogg Vorbis file.'

      if @stream.readUInt8() isnt 0
        return @emit 'error', 'Invalid Ogg Vorbis version.'

      unless @stage?
        @stage = @stream.readUInt8()
        if @stage isnt PAGE_BOS
          return @emit 'error', 'File must begin with BOS header'
      else
        @stage = @stream.readUInt8()

      @position     = @stream.readUInt32()
      @position     = @stream.readUInt32()
      @bitstreamNum = @stream.readUInt32()
      @pageNum      = @stream.readUInt32()
      @checksum     = @stream.readUInt32()
      @numOfSeg     = @stream.readUInt8()
      @segLength    = []
      for i in [0...@numOfSeg]
        @segLength.push @stream.readUInt8()

      @readPageHeader = true

    while @readPageHeader and @stream.available @segLength[0]
      # Assigned for debugging
      packetType = @stream.readInt8()
      switch packetType
        when HEADER_ID
          checkHeaderSignature.call @

          @stream.advance(4) # vorbis version
          @channels   = @stream.readUInt8()
          @sampleRate = @stream.readUInt32(true)
          @bitRateMax = @stream.readInt32(true)
          @bitRateNom = @stream.readInt32(true)
          @bitRateMin = @stream.readInt32(true)
          @bitRate    = if @bitRateMax is @bitRateMin then @bitRateMax else @bitRateNom
          @bitDepth   = @bitRate / @sampleRate / @channels

          # Block size needs to be cut into 4 bit chunks and checked
          # that blocksize[0] <= blocksize[1]
          console.log @stream.readUInt8(), 'blocksize0,1'
          # Not sure what framing flag is used for
          console.log @stream.readUInt8(), 'flag'

          @format =
            formatID   :'oggv'
            channels   : @channels
            sampleRate : @sampleRate
            bitDepth   : @bitDepth

          @segLength.shift()
          @emit 'format', @format

        when HEADER_COMMENTS
          checkHeaderSignature.call @
          vendorLength = @stream.readUInt32()
          @vendor = @stream.readString(0, vendorLength)
          metaItems = @stream.readUInt32()
          metadata = {}

          for i in [0...metaItems]
            itemLength = @stream.readUInt32()
            itemValue = @stream.readString(itemLength)
            itemValue = itemValue.match META_REGEX
            if itemValue and itemValue.length
              metadata[ itemValue[1] ] = itemValue[2]

          console.log @stream.readUInt8(), 'framing bit'

          @segLength.shift()
          @emit 'metadata', metadata
 
        when HEADER_SETUP
          return
        when AUDIO_PACKET
          return
        else
          console.log packetType
          return

      @readPageHeader = false unless @segLength.length
      return

  checkHeaderSignature = ->
    if @stream.readString(6) isnt HEADER_SIG
      return @emite 'error', 'Invalid packet header in file.'

