#!/usr/bin/ruby
#
# 24.03.2017 - Bodo Schulz
# v1.3.0
#
# simplified API for Beanaeter (Client Class for beanstalk)

# -----------------------------------------------------------------------------

require 'beaneater'
require 'json'
require 'digest/md5'
# require 'semantic_logger'

require_relative 'logging'
require_relative 'message_queue/producer'
require_relative 'message_queue/consumer'

# -----------------------------------------------------------------------------

module MessageQueue
end

# -----------------------------------------------------------------------------
# TESTS

# settings = {
#   :beanstalkHost => 'localhost'
# }
#
# p = MessageQueue::Producer.new( settings )
#
#
# 100.times do |i|
#
#   job = {
#     cmd:   'add',
#     payload: sprintf( "foo-bar-%s.com", i )
#   }.to_json
#
#   p.addJob( 'test-tube', job )
# end
#
# c = MessageQueue::Consumer.new( settings )
#
# puts JSON.pretty_generate( c.tubeStatistics( 'test-tube' ) )
#
# loop do
#   j = c.getJobFromTube( 'test-tube' )
#
#   if( j.count == 0 )
#     break
#   else
#     puts JSON.pretty_generate( j )
#   end
# end

# -----------------------------------------------------------------------------
