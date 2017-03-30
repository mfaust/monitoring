#!/usr/bin/ruby
#
# 14.03.2017 - Bodo Schulz
#
#
# v1.2.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/collector'

# -----------------------------------------------------------------------------

applicationConfigFile = '/etc/cm-application.yaml'
serviceConfigFile     = '/etc/cm-service.yaml'


jolokiaHost      = ENV.fetch('JOLOKIA_HOST'     , 'localhost' )
jolokiaPort      = ENV.fetch('JOLOKIA_PORT'     , 8080 )
jolokiaPath      = ENV.fetch('JOLOKIA_PATH'     , '/jolokia' )
jolokiaAuthUser  = ENV.fetch('JOLOKIA_AUTH_USER', nil )
jolokiaAuthPass  = ENV.fetch('JOLOKIA_AUTH_PASS', nil )
mqHost           = ENV.fetch('MQ_HOST'          , 'localhost' )
mqPort           = ENV.fetch('MQ_PORT'          , 11300 )
mqQueue          = ENV.fetch('MQ_QUEUE'         , 'mq-collector' )
memcacheHost     = ENV.fetch('MEMCACHE_HOST'    , 'localhost' )
memcachePort     = ENV.fetch('MEMCACHE_PORT'    , 11211 )
scanDiscovery    = ENV.fetch('SCAN_DISCOVERY'   , '10m' )
interval         = ENV.fetch('INTERVAL'         , 15 )

config = {
  :jolokiaHost           => jolokiaHost,
  :jolokiaPort           => jolokiaPort,
  :jolokiaPath           => jolokiaPath,
  :jolokiaAuthUser       => jolokiaAuthUser,
  :jolokiaAuthPass       => jolokiaAuthPass,
  :mqHost                => mqHost,
  :mqPort                => mqPort,
  :mqQueue               => mqQueue,
  :memcacheHost          => memcacheHost,
  :memcachePort          => memcachePort,
  :scanDiscovery         => scanDiscovery,
  :applicationConfigFile => applicationConfigFile,
  :serviceConfigFile     => serviceConfigFile
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

r = DataCollector::Collector.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval.to_i, :first_in => 1 ) do

  r.run()

end


scheduler.every( '5s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end

end

scheduler.join

# -----------------------------------------------------------------------------

# EOF
