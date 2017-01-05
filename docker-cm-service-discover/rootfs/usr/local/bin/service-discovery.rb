#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require_relative '../lib/discover'

# -----------------------------------------------------------------------------

logDirectory       = '/var/log/monitoring'
cacheDirectory     = '/var/cache/monitoring'
serviceConfigFile  = '/etc/cm-service.yaml'

jolokiaHost        = ENV['JOLOKIA_HOST'] ? ENV['JOLOKIA_HOST'] : 'localhost'
jolokiaPort        = ENV['JOLOKIA_PORT'] ? ENV['JOLOKIA_PORT'] : 8080
mqHost             = ENV['MQ_HOST']      ? ENV['MQ_HOST']      : 'localhost'
mqPort             = ENV['MQ_PORT']      ? ENV['MQ_PORT']      : 11300
mqQueue            = ENV['MQ_QUEUE']     ? ENV['MQ_QUEUE']     : 'mq-discover'

config = {
  :jolokiaHost       => jolokiaHost,
  :jolokiaPort       => jolokiaPort,
  :mqHost            => mqHost,
  :mqPort            => mqPort,
  :mqQueue           => mqQueue,
  :serviceConfigFile => serviceConfigFile
}

# ---------------------------------------------------------------------------------------
# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

sd = ServiceDiscovery.new( config )

until stop
  sd.queue()
  sleep( 5 )
end

# -----------------------------------------------------------------------------

# EOF
