#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'yaml'
require 'rufus-scheduler'

require_relative '../lib/external-discover'

# -----------------------------------------------------------------------------

logDirectory     = '/var/log/monitoring'

apiHost          = ENV.fetch('MONITORING_HOST', nil)
apiPort          = ENV.fetch('MONITORING_PORT', nil)
apiVersion       = ENV.fetch('MONITORING_API_VERSION', 2)

discoveryHost    = ENV.fetch('DISCOVERY_HOST', nil)
discoveryPort    = ENV.fetch('DISCOVERY_PORT', nil)
discoveryPath    = ENV.fetch('DISCOVERY_PATH', nil)
interval         = ENV.fetch('DISCOVERY_POLL_INTERVAL', 30)

if( apiHost == nil || apiPort == nil || discoveryHost == nil || discoveryPort == nil || discoveryPath == nil )
  puts '=> missing configuration!'
  puts '=> please use the ENV Variables'

  exit 1
end

config = {
  :apiHost       => apiHost,
  :apiPort       => 80,
  :apiVersion    => apiVersion,
  :discoveryHost => discoveryHost,
  :discoveryPort => discoveryPort,
  :discoveryPath => discoveryPath
}

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval.to_i, :first_in => 5 ) do

  e.run()

end


scheduler.every( 5 ) do

  if( stop == true )

    p 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end


scheduler.join

# -----------------------------------------------------------------------------

# EOF
