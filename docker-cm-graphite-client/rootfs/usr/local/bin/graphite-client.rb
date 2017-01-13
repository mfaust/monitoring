#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v2.0.1

# -----------------------------------------------------------------------------

require_relative '../lib/graphite'

# -----------------------------------------------------------------------------

graphiteHost      = ENV['GRAPHITE_HOST']      ? ENV['GRAPHITE_HOST']       : 'localhost'
graphitePort      = ENV['GRAPHITE_PORT']      ? ENV['GRAPHITE_PORT']       : 2003
graphiteHttpPort  = ENV['GRAPHITE_HTTP_PORT'] ? ENV['GRAPHITE_HTTP_PORT']  : 8081
graphitePath      = ENV['GRAPHITE_PATH']      ? ENV['GRAPHITE_PATH']       : nil
mqHost            = ENV['MQ_HOST']            ? ENV['MQ_HOST']             : 'localhost'
mqPort            = ENV['MQ_PORT']            ? ENV['MQ_PORT']             : 11300
mqQueue           = ENV['MQ_QUEUE']           ? ENV['MQ_QUEUE']            : 'mq-graphite'

config = {
  :graphiteHost      => graphiteHost,
  :graphitePort      => graphitePort,
  :graphiteHttpPort  => graphiteHttpPort,
  :graphitePath      => graphitePath,
  :mqHost            => mqHost,
  :mqPort            => mqPort,
  :mqQueue           => mqQueue,
  :debug             => true
}

# ---------------------------------------------------------------------------------------

g = Graphite::Client.new( config )

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

if( g != nil )

  until stop
    # do your thing
    g.queue()
    sleep( 5 )
  end

else
  exit 2
end

# -----------------------------------------------------------------------------

# EOF
