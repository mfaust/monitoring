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
  cmd: 'oergs',
  node: 'monitoring-16-01',
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
      "display-name": "foo-bar",
      "ports": [
        3306,
        9100,
        28017
      ]
    },
    "annotation": true,
    "overview": true
  }
}.to_json

response = tube.put( job, :ttr => 30, :delay => 0 )

puts response



