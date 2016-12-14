#!/usr/bin/ruby
#
# 14.12.2016 - Bodo Schulz
#
#
# v0.5.0

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/external-discover'

# -----------------------------------------------------------------------------


memcacheHost = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : 'localhost'
memcachePort = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : 11211

config = {
  :logDirectory => '/var/log/monitoring',
  :memcacheHost => memcacheHost,
  :memcachePort => memcachePort
}

# ---------------------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

until stop
  # do your thing
  e.run()
  sleep( 30 )
end

# -----------------------------------------------------------------------------

# EOF
