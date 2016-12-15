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

configFile    = '/etc/cm-monitoring.yaml'

logDirectory  = '/var/log/monitoring'
apiHost       = 'localhost'
apiVersion    = 2

discoveryHost = 'localhost'
discoveryPath = '/'

memcacheHost  = nil
memcachePort  = nil

if( File.exist?( configFile ) )

  config = YAML.load_file( configFile )

  logDirectory     = config['logDirectory']         ? config['logDirectory']     : '/var/log/monitoring'

  apiHost          = config.dig( 'external-discover', 'internal', 'host' ) || 'localhost'
  apiVersion       = config.dig( 'external-discover', 'internal', 'version' ) || 2

  discoveryHost    = config.dig( 'external-discover', 'backend', 'host' ) || 'localhost'
  discoveryPath    = config.dig( 'external-discover', 'backend', 'path' ) || '/'

  memcacheHost     = ENV['MEMCACHE_HOST']           ? ENV['MEMCACHE_HOST']       : nil
  memcachePort     = ENV['MEMCACHE_PORT']           ? ENV['MEMCACHE_PORT']       : nil

else
  puts "no configuration exists, use default settings"
end


config = {
  :logDirectory => logDirectory,
  :apiHost      => apiHost,
  :apiPort      => 80,
  :apiVersion   => apiVersion,
  :memcacheHost => memcacheHost,
  :memcachePort => memcachePort
}

# ---------------------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

sleep( 15 )

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
