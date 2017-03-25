#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v2.0.1

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/graphite'

# -----------------------------------------------------------------------------

graphiteHost       = ENV.fetch( 'GRAPHITE_HOST'     , 'localhost' )
graphitePort       = ENV.fetch( 'GRAPHITE_PORT'     , 2003 )
graphiteHttpPort   = ENV.fetch( 'GRAPHITE_HTTP_PORT', 8081 )
graphitePath       = ENV.fetch( 'GRAPHITE_PATH'     , nil )
mqHost             = ENV.fetch( 'MQ_HOST'           , 'localhost' )
mqPort             = ENV.fetch( 'MQ_PORT'           , 11300 )
mqQueue            = ENV.fetch( 'MQ_QUEUE'          , 'mq-graphite' )
interval           = 15

config = {
  :graphiteHost      => graphiteHost,
  :graphitePort      => graphitePort,
  :graphiteHttpPort  => graphiteHttpPort,
  :graphitePath      => graphitePath,
  :mqHost            => mqHost,
  :mqPort            => mqPort,
  :mqQueue           => mqQueue
}

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# ---------------------------------------------------------------------------------------

g = Graphite::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => 10 ) do

  g.queue()

end


scheduler.every( 5 ) do

  if( stop == true )

    p 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end

scheduler.join

# EOF
