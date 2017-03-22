#!/usr/bin/ruby

require 'beaneater'
require 'json'
require 'time'

bs = Beaneater.new( 'localhost' )

tube = bs.tubes['mq-test']

      vars = {
        "coremedia" => {

          "adobe-drive-server": {
            "port": 41199,
            "description": "Adobe Drive Server",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          },
          "cae-live-1": {
            "port": 42199,
            "description": "CAE Live 1",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          }
        }
      }

job = {
  cmd: 'add',
  node: 'monitoring-16-01',
  payload: vars
}.to_json

job = {
  cmd: 'info',
  node: 'monitoring-16-01',
  payload: {}
}.to_json


response = tube.put( job, :ttr => 30, :delay => 0 )

puts response

#tube = bs.tubes['mq-grafana']

# job = {
#   cmd: 'remove',
#   node: 'monitoring-16-01',
#   payload: {
#     "force": true,
#     "tags": [
#       "development",
#       "git-0000000"
#     ],
#     "overview": true
#   }
# }.to_json
#
#
# response = tube.put( job, :ttr => 30, :delay => 0 )
#
# puts response
#
# job = {
#   cmd: 'add',
#   node: 'monitoring-16-01',
#   payload: {
#     "force": true,
#     "tags": [
#       "development",
#       "git-0000000"
#     ],
#     "overview": true
#   }
# }.to_json
#
#
# response = tube.put( job, :ttr => 30, :delay => 0 )
#
# puts response


# tube = bs.tubes['mq-graphite']
#
# job = {
#   cmd: 'remove',
#   node: 'monitoring-16-01',
#   payload: {
#     "timestamp": Time.parse( "2017-01-13 11:00:00 +0100" ).to_i,
#     "force": true,
#     "discovery": false,
#     "icinga": false,
#     "grafana": false,
#     "tags": [
#       "development",
#       "git-0000000"
#     ],
#     "annotation": false,
#     "overview": true
#   }
# }.to_json
#
# puts job
#
# response = tube.put( job, :ttr => 30, :delay => 0 )
#
# puts response

