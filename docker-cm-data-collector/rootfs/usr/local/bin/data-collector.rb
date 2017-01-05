#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.1

# -----------------------------------------------------------------------------

require_relative '../lib/data-collector'

# -----------------------------------------------------------------------------

logDirectory          = '/var/log/monitoring'
cacheDirectory        = '/var/cache/monitoring'
applicationConfigFile = '/etc/cm-application.yaml'
serviceConfigFile     = '/etc/cm-service.yaml'


jolokiaHost      = ENV['JOLOKIA_HOST']    ? ENV['JOLOKIA_HOST']    : 'localhost'
jolokiaPort      = ENV['JOLOKIA_PORT']    ? ENV['JOLOKIA_PORT']    : 8080
memcacheHost     = ENV['MEMCACHE_HOST']   ? ENV['MEMCACHE_HOST']   : 'localhost'
memcachePort     = ENV['MEMCACHE_PORT']   ? ENV['MEMCACHE_PORT']   : 11211
scanDiscovery    = ENV['SCAN_DISCOVERY']  ? ENV ['SCAN_DISCOVERY'] : '10m'

config = {
  :logDirectory          => logDirectory,
  :cacheDirectory        => cacheDirectory,
  :jolokiaHost           => jolokiaHost,
  :jolokiaPort           => jolokiaPort,
  :memcacheHost          => memcacheHost,
  :memcachePort          => memcachePort,
  :scanDiscovery         => scanDiscovery,
  :applicationConfigFile => applicationConfigFile,
  :serviceConfigFile     => serviceConfigFile
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

r = DataCollector.new( config )

until stop
  r.run()
  sleep( 15 )
end

# -----------------------------------------------------------------------------

# EOF
