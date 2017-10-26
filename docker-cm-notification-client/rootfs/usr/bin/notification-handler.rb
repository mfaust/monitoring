#!/usr/bin/env ruby
#
# 14.03.2017 - Bodo Schulz
#
#
# v1.3.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/notification_handler'

# -----------------------------------------------------------------------------

mq_host           = ENV.fetch('MQ_HOST', nil)
mq_port           = ENV.fetch('MQ_PORT', nil)
mq_queue          = ENV.fetch('MQ_QUEUE', nil)
interval          = ENV.fetch('INTERVAL', 30 )
delay             = ENV.fetch('RUN_DELAY', 1 )

config = {
  :mq          => {
    :host  => mq_host,
    :port  => mq_port,
    :queue => mq_queue
  }
}

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

r = NotificationHandler::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => delay ) do

  r.queue()
end


scheduler.every( 5 ) do

  if( stop == true )

    p 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end

scheduler.join

# -----------------------------------------------------------------------------

# EOF
