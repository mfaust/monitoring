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

memcacheHost = ENV.fetch( 'MEMCACHE_HOST'    , 'localhost' )
memcachePort = ENV.fetch( 'MEMCACHE_PORT'    , 11211 )
interval     = ENV.fetch( 'COLLECTD_INTERVAL', 15 )
carbonHost   = ENV.fetch( 'GRAPHITE_HOST'    , 'carbon' )
carbonPort   = ENV.fetch( 'GRAPHITE_PORT'    , 2003 )

config = {
  :memcache        => { :host => memcacheHost, :port => memcachePort },
  :graphite        => { :host => carbonHost, :port => carbonPort },
  :interval        => interval,
  :cache           => ( 2 * 60 * 60 )
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

client = CarbonWriter.new( config )


exit 0

scheduler = Rufus::Scheduler.new

scheduler.every( '45s', :first_in => 0.4 ) do
  client.metric( { :key => "test.master-17-tomcat.WFS.Runtime.starttime" , :value => 1488287135933 } )
  client.metric( { :key => "test.master-17-tomcat.WFS.Manager.processing.time.count" , :value => 4 } )

end


scheduler.every( '1s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end

end


scheduler.join


