helpers = require 'helpers'
bitbuffer = require 'bit-buffer'
eventEmitter = require('events').EventEmitter
_ = require 'underscore'

commands = exports.commands = {}
commands.STOP = [ 0xA5, 0x25 ]
commands.RESET = [ 0xA5, 0x40 ]
commands.SCAN = [ 0xA5, 0x20 ]
commands.FORCE_SCAN = [ 0xA5, 0x21 ]
commands.GET_INFO = [ 0xA5, 0x50 ]
commands.GET_HEALTH = [ 0xA5, 0x51 ]
commands = helpers.dictMap commands, (value,key) -> new Buffer(value)

replies = exports.replies = {}
replies.SCAN_START = [ 0x05, 0x00, 0x00, 0x40, 0x81 ]
replies = helpers.dictMap replies, (value,key) -> new Buffer(value)




packet = () -> @
packet::show = -> console.log @type, "   ", @buffer


responsePacket = (buffer) ->
    @buffer = buffer
    
    helpers.dictMap replies, (sample,command) => if @match(sample) then @command = command
    @
    
responsePacket:: = new packet()
responsePacket::type = "REPLY"
responsePacket::show = ->
    if @command then console.log @type, @command
    else console.log @type, "unknown",@buffer
responsePacket::match = (buffer) ->
    String(@buffer.slice(2)) is String(buffer)
    


dataPacket = (buffer) ->
    @bb = new bitbuffer.BitView(buffer)
    @buffer = buffer
    @parse()

    @



dataPacket:: = new packet()

dataPacket::parse = ->
    bits = @bits()
    if (bits[0] is bits[1]) or bits[8] != 1 then return console.error "invalid data"
    
    @new = Boolean bits[0]
    @quality = @bb.getBits(2,6,false)
    @angle = @bb.getBits(9,15,false) / 100.0
    @distance = @bb.getBits(24,16,false)
            
dataPacket::type = "SCAN"
dataPacket::bits = ->
    if @bits_cache then return @bits_cache
    res = []

    fillRes = =>
        res.push bit = @bb.getBits(location,1)
        location += 1

    location = 0
    fillRes() while location < @bb.buffer.length * 8

    @bits_cache = res
    
dataPacket::show_binary = ->
    "| " + _.map(@bits(),(bit,i) ->
        x = if bit then "+" else "."
        if not ((i + 1) % 8) then x + " | " else x
        ).join('')

dataPacket::show = ->
    console.log @show_binary(), @angle, @distance, @quality


packetStream = exports.packetStream = ->
    @scan_start = false
    
packetStream:: = new eventEmitter()
packetStream::feed = (buffer) ->
    if buffer.length is 7 and buffer[0] is 0xA5 and buffer[1] is 0x5A
        @emit 'packet', packet = new responsePacket(buffer)
        if packet.command == 'SCAN_START' then @scan_start = true
    else if @scan_start is true
        if @oldbuffer
            buffer = Buffer.concat [@oldbuffer, buffer]
            delete @oldbuffer
    
        packetSize = 5
        
        makePacket = (buffer,location) =>
            @emit 'packet', new dataPacket(buffer.slice(location, location + packetSize))
            location + packetSize

        location = 0
        
        location = makePacket(buffer,location) while location + packetSize < buffer.length
        if location < buffer.length
            @oldbuffer = buffer.slice(location)


exports.dataView = class dataView extends eventEmitter
    constructor: (@packetStream) ->
        @data = {}
        @packetStream.on 'packet', (packet) =>
            if packet.new
                @emit 'view', @data
                @data = {}
            @data[packet.angle] = packet.distance

    show: () ->
        display = {}
        _.map @data, (distance,angle) ->
            helpers.dictpush display, String(Math.round(Number(angle) / 10)), distance
            
        display = helpers.dictMap display, (distances, angle) ->
            total = _.reduce distances,
                (total, distance) -> total + distance,
                0
                
            Math.round((total / distances.length) / 500)

        helpers.dictMap display, (distance, angle) ->
            if not distance then return
            ln = ""
            _.times distance, -> ln+="*"
            console.log helpers.pad(angle,2), ln