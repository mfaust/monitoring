#!/usr/bin/ruby
#
# 13.01.2017 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/cm_grafana'

# -----------------------------------------------------------------------------

grafanaHost         = ENV.fetch('GRAFANA_HOST'           , 'grafana')
grafanaPort         = ENV.fetch('GRAFANA_PORT'           , 80)
grafanaUrlPath      = ENV.fetch('GRAFANA_URL_PATH'       , '/grafana')
grafanaApiUser      = ENV.fetch('GRAFANA_API_USER'       , 'admin')
grafanaApiPassword  = ENV.fetch('GRAFANA_API_PASSWORD'   , 'admin')
grafanaTemplatePath = ENV.fetch('GRAFANA_TEMPLATE_PATH'  , '/usr/local/share/templates/grafana')
mqHost              = ENV.fetch('MQ_HOST'                , 'beanstalkd')
mqPort              = ENV.fetch('MQ_PORT'                , 11300)
mqQueue             = ENV.fetch('MQ_QUEUE'               , 'mq-grafana')
redisHost           = ENV.fetch('REDIS_HOST'             , 'redis' )
redisPort           = ENV.fetch('REDIS_PORT'             , 6379 )
mysqlHost           = ENV.fetch('MYSQL_HOST'             , 'database')
mysqlSchema         = ENV.fetch('DISCOVERY_DATABASE_NAME', 'discovery')
mysqlUser           = ENV.fetch('DISCOVERY_DATABASE_USER', 'discovery')
mysqlPassword       = ENV.fetch('DISCOVERY_DATABASE_PASS', 'discovery')
interval            = ENV.fetch('INTERVAL'               , 40 )
delay               = ENV.fetch('RUN_DELAY'              , 30 )

server_config_file  = ENV.fetch('SERVER_CONFIG_FILE'     , '/etc/grafana/server_config.yml' )

config = {
  :grafana => {
    :host              => grafanaHost,
    :port              => grafanaPort,
    :user              => grafanaApiUser,
    :password          => grafanaApiPassword,
    :timeout           => 10,
    :ssl               => false,
    :url_path          => grafanaUrlPath,
    :templateDirectory => grafanaTemplatePath,
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

# -----------------------------------------------------------------------------

g = CMGrafana.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => delay ) do

  g.queue()

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
