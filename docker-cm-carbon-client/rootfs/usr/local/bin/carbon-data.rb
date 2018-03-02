#!/usr/bin/ruby
#
# 09.01.2017 - Bodo Schulz
#
#
# v1.5.0

# p "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
# p $$

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/carbon-writer'

# -----------------------------------------------------------------------------

redis_host        = ENV.fetch('REDIS_HOST'             , 'redis' )
redis_port        = ENV.fetch('REDIS_PORT'             , 6379 )
carbon_host       = ENV.fetch('GRAPHITE_HOST'          , 'carbon' )
carbon_port       = ENV.fetch('GRAPHITE_PORT'          , 2003 )
mysql_host        = ENV.fetch('MYSQL_HOST'             , 'database')
mysql_schema      = ENV.fetch('DISCOVERY_DATABASE_NAME', 'discovery')
mysql_user        = ENV.fetch('DISCOVERY_DATABASE_USER', 'discovery')
mysql_password    = ENV.fetch('DISCOVERY_DATABASE_PASS', 'discovery')
interval          = ENV.fetch('INTERVAL'               , 30 )
delay             = ENV.fetch('RUN_DELAY'              , 10 )

config = {
  redis: {
    host: redis_host,
    port: redisPort
  },
  graphite: {
    host: carbonHost,
    port: carbonPort
  },
  mysql: {
    host: mysqlHost,
    schema: mysqlSchema,
    user: mysqlUser,
    password: mysqlPassword
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

writer = CarbonWriter.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => delay ) do

  writer.run()
end


scheduler.every( '5s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end
end

scheduler.join
