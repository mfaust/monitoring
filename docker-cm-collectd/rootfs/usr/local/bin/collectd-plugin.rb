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

c = Collecd::Plugin.new( config )

loop do
  c.run()
  sleep( interval.to_i )
end

# EOF
