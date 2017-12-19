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

graphite_host      = ENV.fetch('GRAPHITE_HOST', 'nginx' )
graphite_port      = ENV.fetch('GRAPHITE_PORT', 2003 )
graphite_http_port = ENV.fetch('GRAPHITE_HTTP_PORT', 80 )
graphite_path      = ENV.fetch('GRAPHITE_PATH', '/graphite' )
mq_host            = ENV.fetch('MQ_HOST', nil )
mq_port            = ENV.fetch('MQ_PORT', nil )
mq_queue           = ENV.fetch('MQ_QUEUE', nil )
interval           = ENV.fetch('INTERVAL', 30 )
delay              = ENV.fetch('RUN_DELAY', 10 )

config = {
  :graphite => {
    :host      => graphite_host,
    :port      => graphite_port,
    :http_port => graphite_http_port,
    :path      => graphite_path
  },
  :mq       => {
    :host  => mq_host,
    :port  => mq_port,
    :queue => mq_queue
  }
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

scheduler.every( interval, :first_in => delay ) do

  g.queue

end


scheduler.every( 5 ) do

  if stop

    p 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end

scheduler.join

# EOF
