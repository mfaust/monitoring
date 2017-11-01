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

icingaHost          = ENV.fetch('ICINGA_HOST'             , 'localhost' )
icingaApiPort       = ENV.fetch('ICINGA_API_PORT'         , 5665 )
icingaApiUser       = ENV.fetch('ICINGA_API_USER'         , 'admin' )
icingaApiPass       = ENV.fetch('ICINGA_API_PASSWORD'     , nil )
icingaCluster       = ENV.fetch('ICINGA_CLUSTER'          , false )
icingaSatellite     = ENV.fetch('ICINGA_CLUSTER_SATELLITE', nil )
icingaNotifications = ENV.fetch('ENABLE_NOTIFICATIONS'    , false )
mqHost              = ENV.fetch('MQ_HOST'                 , 'beanstalkd' )
mqPort              = ENV.fetch('MQ_PORT'                 , 11300 )
mqQueue             = ENV.fetch('MQ_QUEUE'                , 'mq-icinga' )
redisHost           = ENV.fetch('REDIS_HOST'              , 'redis' )
redisPort           = ENV.fetch('REDIS_PORT'              , 6379 )
mysqlHost           = ENV.fetch('MYSQL_HOST'              , 'database')
mysqlSchema         = ENV.fetch('DISCOVERY_DATABASE_NAME' , 'discovery')
mysqlUser           = ENV.fetch('DISCOVERY_DATABASE_USER' , 'discovery')
mysqlPassword       = ENV.fetch('DISCOVERY_DATABASE_PASS' , 'discovery')
interval            = ENV.fetch('INTERVAL'                , 20 )
delay               = ENV.fetch('RUN_DELAY'               , 25 )

server_config_file  = ENV.fetch('SERVER_CONFIG_FILE'     , '/etc/icinga_server_config.yml' )

# convert string to bool
icingaCluster       = icingaCluster.to_s.eql?('true') ? true : false
icingaNotifications = icingaNotifications.to_s.eql?('true') ? true : false

config = {
  :icinga      => {
    :host          => icingaHost,
    :cluster       => icingaCluster,
    :satellite     => icingaSatellite,
    :notifications => icingaNotifications,
    :api => {
      :port     => icingaApiPort,
      :user     => icingaApiUser,
      :password => icingaApiPass
    },
    :server_config_file => server_config_file
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
  :mysql    => {
    :host      => mysqlHost,
    :schema    => mysqlSchema,
    :user      => mysqlUser,
    :password  => mysqlPassword
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

i = CMIcinga2.new( config )

cfg_scheduler = Rufus::Scheduler.singleton

cfg_scheduler.every( '60m', :first_in => delay.to_i ) do

  i.configure_server( config_file: server_config_file ) unless( server_config_file.nil? )
  cfg_scheduler.shutdown(:kill)
end


scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => delay.to_i + 5 ) do

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
