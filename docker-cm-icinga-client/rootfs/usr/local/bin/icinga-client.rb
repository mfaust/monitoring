#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/icinga'

# -----------------------------------------------------------------------------

icingaHost          = ENV.fetch( 'ICINGA_HOST'             , 'localhost' )
icingaApiPort       = ENV.fetch( 'ICINGA_API_PORT'         , 5665 )
icingaApiUser       = ENV.fetch( 'ICINGA_API_USER'         , 'admin' )
icingaApiPass       = ENV.fetch( 'ICINGA_API_PASSWORD'     , nil )
icingaCluster       = ENV.fetch( 'ICINGA_CLUSTER'          , false )
icingaSatellite     = ENV.fetch( 'ICINGA_CLUSTER_SATELLITE', nil )
icingaNotifications = ENV.fetch( 'ENABLE_NOTIFICATIONS'    , false )
mqHost              = ENV.fetch( 'MQ_HOST'                 , 'localhost' )
mqPort              = ENV.fetch( 'MQ_PORT'                 , 11300 )
mqQueue             = ENV.fetch( 'MQ_QUEUE'                , 'mq-icinga' )
interval            = 10

# convert string to bool
icingaCluster   = icingaCluster.to_s.eql?('true') ? true : false
notifications   = notifications.to_s.eql?('true') ? true : false

config = {
  :icingaHost          => icingaHost,
  :icingaApiPort       => icingaApiPort,
  :icingaApiUser       => icingaApiUser,
  :icingaApiPass       => icingaApiPass,
  :icingaCluster       => icingaCluster,
  :icingaSatellite     => icingaSatellite,
  :icingaNotifications => icingaNotifications,
  :mqHost              => mqHost,
  :mqPort              => mqPort,
  :mqQueue             => mqQueue
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

i = Icinga::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => 5 ) do

  i.queue()

end


scheduler.every( 5 ) do

  if( stop == true )

    p 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end


scheduler.join


# EOF
