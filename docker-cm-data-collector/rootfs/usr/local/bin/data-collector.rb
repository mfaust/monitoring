#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.1.0

# -----------------------------------------------------------------------------

require_relative '../lib/collector'

# -----------------------------------------------------------------------------

logDirectory          = '/var/log/monitoring'
cacheDirectory        = '/var/cache/monitoring'
applicationConfigFile = '/etc/cm-application.yaml'
serviceConfigFile     = '/etc/cm-service.yaml'


jolokiaHost      = ENV['JOLOKIA_HOST']    ? ENV['JOLOKIA_HOST']    : 'localhost'
jolokiaPort      = ENV['JOLOKIA_PORT']    ? ENV['JOLOKIA_PORT']    : 8080
mqHost           = ENV['MQ_HOST']         ? ENV['MQ_HOST']         : 'localhost'
mqPort           = ENV['MQ_PORT']         ? ENV['MQ_PORT']         : 11300
mqQueue          = ENV['MQ_QUEUE']        ? ENV['MQ_QUEUE']        : 'mq-collector'
memcacheHost     = ENV['MEMCACHE_HOST']   ? ENV['MEMCACHE_HOST']   : 'localhost'
memcachePort     = ENV['MEMCACHE_PORT']   ? ENV['MEMCACHE_PORT']   : 11211
scanDiscovery    = ENV['SCAN_DISCOVERY']  ? ENV['SCAN_DISCOVERY']  : '10m'
intervall        = ENV['INTERVALL']       ? ENV['INTERVALL']       : 15

config = {
  :logDirectory          => logDirectory,
  :cacheDirectory        => cacheDirectory,
  :jolokiaHost           => jolokiaHost,
  :jolokiaPort           => jolokiaPort,
  :mqHost                => mqHost,
  :mqPort                => mqPort,
  :mqQueue               => mqQueue,
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

r = DataCollector::Collector.new( config )

if( r != nil )

  until stop
    r.run()
    sleep( intervall.to_i )
  end

else
  exit 2
end

# -----------------------------------------------------------------------------

# EOF
