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

redisHost          = ENV.fetch( 'REDIS_HOST'       , 'localhost' )
redisPort          = ENV.fetch( 'REDIS_PORT'       , 6379 )
interval           = ENV.fetch( 'INTERVAL'         , 20 )
carbonHost         = ENV.fetch( 'GRAPHITE_HOST'    , 'carbon' )
carbonPort         = ENV.fetch( 'GRAPHITE_PORT'    , 2003 )

config = {
  :redis       => {
    :host => redisHost,
    :port => redisPort
  },
  :graphite    => {
    :host => carbonHost,
    :port => carbonPort
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

scheduler.every( interval, :first_in => 1 ) do

  writer.run()

end


scheduler.every( '5s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end

end


scheduler.join
