#!/usr/bin/ruby
#
# 09.01.2017 - Bodo Schulz
#
#
# v1.5.0

# -----------------------------------------------------------------------------

require_relative '../lib/collectd-plugin'

# -----------------------------------------------------------------------------

memcacheHost = ENV['MEMCACHE_HOST']     ? ENV['MEMCACHE_HOST']     : 'localhost'
memcachePort = ENV['MEMCACHE_PORT']     ? ENV['MEMCACHE_PORT']     : 11211
interval     = ENV['COLLECTD_INTERVAL'] ? ENV['COLLECTD_INTERVAL'] : 15

config = {
  :memcacheHost    => memcacheHost,
  :memcachePort    => memcachePort,
  :interval        => interval
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

c = Collecd::Plugin.new( config )

until stop
  c.run()
  sleep( interval.to_i )
end

#loop do
#  c.run()
#  sleep( interval.to_i )
#end

# EOF
