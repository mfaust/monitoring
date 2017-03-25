#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/discover'

# -----------------------------------------------------------------------------

logDirectory       = '/var/log/monitoring'
cacheDirectory     = '/var/cache/monitoring'
serviceConfigFile  = '/etc/cm-service.yaml'

jolokiaHost        = ENV.fetch( 'JOLOKIA_HOST', 'localhost' )
jolokiaPort        = ENV.fetch( 'JOLOKIA_PORT', 8080 )
mqHost             = ENV.fetch( 'MQ_HOST'     , 'localhost' )
mqPort             = ENV.fetch( 'MQ_PORT'     , 11300 )
mqQueue            = ENV.fetch( 'MQ_QUEUE'    , 'mq-discover' )
interval           = 10

config = {
  :jolokiaHost       => jolokiaHost,
  :jolokiaPort       => jolokiaPort,
  :mqHost            => mqHost,
  :mqPort            => mqPort,
  :mqQueue           => mqQueue,
  :serviceConfigFile => serviceConfigFile
}

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

sd = ServiceDiscovery.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => 5 ) do

  sd.queue()

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
