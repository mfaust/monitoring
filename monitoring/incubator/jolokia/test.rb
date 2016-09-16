#!/usr/bin/env ruby


require 'logger'
require 'json'

#require './lib/discover'
require './lib/graphite'





# $:.unshift File.expand_path('../../lib',__FILE__)
# require 'graphite'

g = GraphiteAnnotions::Client.new()


g.loadTestStartAnnotation( 'monitoring-16-01' )

#sleep ( 10 )
#g.nodeCreatedAnnotation( 'monitoring-75-01' )

