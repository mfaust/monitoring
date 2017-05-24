#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/discovery'

# -----------------------------------------------------------------------------

serviceConfigFile  = '/etc/cm-service.yaml'

jolokiaHost        = ENV.fetch( 'JOLOKIA_HOST'     , 'jolokia' )
jolokiaPort        = ENV.fetch( 'JOLOKIA_PORT'     , 8080 )
jolokiaPath        = ENV.fetch( 'JOLOKIA_PATH'     , '/jolokia' )
jolokiaAuthUser    = ENV.fetch( 'JOLOKIA_AUTH_USER', nil )
jolokiaAuthPass    = ENV.fetch( 'JOLOKIA_AUTH_PASS', nil )
mqHost             = ENV.fetch( 'MQ_HOST'          , 'beanstalkd' )
mqPort             = ENV.fetch( 'MQ_PORT'          , 11300 )
mqQueue            = ENV.fetch( 'MQ_QUEUE'         , 'mq-discover' )
redisHost          = ENV.fetch( 'REDIS_HOST'       , 'redis' )
redisPort          = ENV.fetch( 'REDIS_PORT'       , 6379 )
interval           = ENV.fetch( 'INTERVAL'         , 20 )
delay              = ENV.fetch( 'RUN_DELAY'        , 10 )

config = {
  :jolokia     => {
    :host => jolokiaHost,
    :port => jolokiaPort,
    :path => jolokiaPath,
    :auth => {
      :user => jolokiaAuthUser,
      :pass => jolokiaAuthPass
    }
  },
  :mq          => {
    :host  => mqHost,
    :port  => mqPort,
    :queue => mqQueue
  },
  :redis       => {
    :host => redisHost,
    :port => redisPort
  },
  :configFiles => {
    :service     => serviceConfigFile
  }
}

if( interval.to_i < 20 )
  interval = 20
end

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

sd = ServiceDiscovery::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => delay ) do

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
