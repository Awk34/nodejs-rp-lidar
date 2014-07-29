SerialPort = new require('serialport').SerialPort
helpers = require 'helpers'

lidar = require 'robopeak-lidar'

port = new SerialPort '/dev/ttyUSB0', baudrate: 115200, buffersize: 256

packetStream = new lidar.packetStream()

#packetStream.on 'packet', (packet) ->
#    packet.show()

view = new lidar.dataView packetStream

view.on 'view', () ->
    view.show()


port.on 'data', (data) -> packetStream.feed data

port.on 'open', ->
    console.log 'port open'
    helpers.wait 100, ->
        console.log 'reseting core'
        port.write lidar.commands.RESET
        helpers.wait 1000, ->
            console.log 'starting scan'
            port.write lidar.commands.SCAN
