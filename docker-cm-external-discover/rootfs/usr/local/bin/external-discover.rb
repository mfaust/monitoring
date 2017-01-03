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

memcacheHost  = 'localhost'
memcachePort  = 11211

interval      = 10

if( File.exist?( configFile ) )

  config = YAML.load_file( configFile )

  logDirectory     = config['logDirectory']         ? config['logDirectory']         : '/var/log/monitoring'

  apiHost          = ENV['MONITORING_HOST']         ? ENV['MONITORING_HOST']         || 'localhost' # config.dig( 'external-discover', 'internal', 'host' )
  apiPort          = ENV['MONITORING_PORT']         ? ENV['MONITORING_PORT']         || 80          # config.dig( 'external-discover', 'internal', 'host' )
  apiVersion       = ENV['MONITORING_API_VERSION']  ? ENV['MONITORING_API_VERSION']  || 2 # config.dig( 'external-discover', 'internal', 'version' )

  discoveryHost    = ENV['DISCOVERY_HOST']          ? ENV['DISCOVERY_HOST']          || 'localhost'  # config.dig( 'external-discover', 'backend', 'host' ) || 'localhost'
  discoveryPort    = ENV['DISCOVERY_PORT']          ? ENV['DISCOVERY_PORT']          || 8080  # config.dig( 'external-discover', 'backend', 'host' ) || 'localhost'
  discoveryPath    = ENV['DISCOVERY_PATH']          ? ENV['DISCOVERY_PATH']          || '/'  # config.dig( 'external-discover', 'backend', 'path' ) || '/'
  interval         = ENV['DISCOVERY_POLL_INTERVAL'] ? ENV['DISCOVERY_POLL_INTERVAL'] || 30

  memcacheHost     = ENV['MEMCACHE_HOST']           ? ENV['MEMCACHE_HOST']           || 'localhost'
  memcachePort     = ENV['MEMCACHE_PORT']           ? ENV['MEMCACHE_PORT']           || 11211



else
  puts "no configuration exists, use default settings"
end


config = {
  :logDirectory  => logDirectory,
  :apiHost       => apiHost,
  :apiPort       => 80,
  :apiVersion    => apiVersion,
  :discoveryHost => discoveryHost,
  :discoveryPort => discoveryPort,
  :discoveryPath => discoveryPath,
  :memcacheHost  => memcacheHost,
  :memcachePort  => memcachePort
}

# ---------------------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

# sleep( 15 )

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
  sleep( interval.to_i )
end

# -----------------------------------------------------------------------------

# EOF
