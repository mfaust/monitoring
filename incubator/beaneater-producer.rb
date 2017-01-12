#!/usr/bin/ruby

require 'beaneater'
require 'json'

bs = Beaneater.new( 'localhost' )

tube = bs.tubes['mq-grafana']
job = {
  some: 'key',
  value: 'object'
}.to_json


job = {
  cmd: 'add',
  node: 'master-17-tomcat',
  payload: {
    "force": true,
    "discovery": false,
    "icinga": false,
    "grafana": false,
    "tags": [
      "development",
      "git-0000000"
    ],
    "annotation": false,
    "overview": true
  }
}.to_json

job = {
  cmd: 'remove',
  node: 'monitoring-16-01',
  payload: {
    "force": true,
    "tags": [
      "development",
      "git-0000000"
    ],
    "overview": true
  }
}.to_json


response = tube.put( job, :ttr => 30, :delay => 0 )

puts response

job = {
  cmd: 'add',
  node: 'monitoring-16-01',
  payload: {
    "force": true,
    "tags": [
      "development",
      "git-0000000"
    ],
    "overview": true
  }
}.to_json


response = tube.put( job, :ttr => 30, :delay => 0 )

puts response

