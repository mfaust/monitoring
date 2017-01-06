#!/usr/bin/ruby

require 'beaneater'
require 'json'

bs = Beaneater.new( 'localhost' )

tube = bs.tubes['mq-discover']
job = {
  some: 'key',
  value: 'object'
}.to_json


job = {
  cmd: 'add',
  node: '192.168.252.170.xip.io',
  payload: {
    "force": true,
    "discovery": false,
    "icinga": false,
    "grafana": false,
    "tags": [
      "development",
      "git-0000000"
    ],
    "config": {
      "display-name": "blueprint-box"
    },
    "annotation": false,
    "overview": true
  }
}.to_json

response = tube.put( job, :ttr => 30, :delay => 0 )

puts response



