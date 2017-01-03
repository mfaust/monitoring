#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/external-discover'

# -----------------------------------------------------------------------------

logDirectory     = '/var/log/monitoring'

apiHost          = ENV['MONITORING_HOST']         ? ENV['MONITORING_HOST']         : nil
apiPort          = ENV['MONITORING_PORT']         ? ENV['MONITORING_PORT']         : nil
apiVersion       = ENV['MONITORING_API_VERSION']  ? ENV['MONITORING_API_VERSION']  : 2

discoveryHost    = ENV['DISCOVERY_HOST']          ? ENV['DISCOVERY_HOST']          : nil
discoveryPort    = ENV['DISCOVERY_PORT']          ? ENV['DISCOVERY_PORT']          : nil
discoveryPath    = ENV['DISCOVERY_PATH']          ? ENV['DISCOVERY_PATH']          : nil
interval         = ENV['DISCOVERY_POLL_INTERVAL'] ? ENV['DISCOVERY_POLL_INTERVAL'] : 30

if( apiHost == nil || apiPort == nil || discoveryHost == nil || discoveryPort == nil || discoveryPath == nil )
  puts '=> missing configuration!'
  puts '=> please use the ENV Variables'

  exit 1
end

config = {
  :logDirectory  => logDirectory,
  :apiHost       => apiHost,
  :apiPort       => 80,
  :apiVersion    => apiVersion,
  :discoveryHost => discoveryHost,
  :discoveryPort => discoveryPort,
  :discoveryPath => discoveryPath
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
  sleep( interval.to_i )
end

# -----------------------------------------------------------------------------

# EOF
