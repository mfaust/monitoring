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

apiHost          = ENV.fetch('MONITORING_HOST', nil)
apiPort          = ENV.fetch('MONITORING_PORT', 80)
apiVersion       = ENV.fetch('MONITORING_API_VERSION', 2)
awsRegion        = ENV.fetch('AWS_REGION', 'us-east-1')
awsEnvironment   = ENV.fetch('AWS_ENVIRONMENT', 'development')
interval         = ENV.fetch('INTERVAL'         , 40 )
delay            = ENV.fetch('RUN_DELAY'        , 10 )

if( apiHost == nil || apiPort == nil || awsRegion == nil )
  puts '=> missing configuration!'
  puts '=> please use the ENV Variables'

  exit 1
end

config = {
  :monitoring => {
    :host    => apiHost,
    :port    => apiPort,
    :version => apiVersion,
  },
  :aws        => {
    :region  => awsRegion,
    :environment => awsEnvironment,
    :filter  => []
  }
}

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true } # 2
Signal.trap('HUP')  { stop = true } # 1
Signal.trap('TERM') { stop = true } # 15
Signal.trap('QUIT') { stop = true } # 3

# -----------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

scheduler = Rufus::Scheduler.new

scheduler.every( interval.to_i, :first_in => delay.to_i ) do

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
