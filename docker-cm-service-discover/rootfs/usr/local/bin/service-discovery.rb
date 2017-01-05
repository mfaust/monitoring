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

jolokiaHost        = ENV['JOLOKIA_HOST']    ? ENV['JOLOKIA_HOST']    : 'localhost'
jolokiaPort        = ENV['JOLOKIA_PORT']    ? ENV['JOLOKIA_PORT']    : 8080
beanstalkHost      = ENV['BEANSTALK_HOST']  ? ENV['BEANSTALK_HOST']  : 'localhost'
beanstalkPort      = ENV['BEANSTALK_PORT']  ? ENV['BEANSTALK_PORT']  : 11300
beanstalkQueue     = ENV['BEANSTALK_QUEUE'] ? ENV['BEANSTALK_QUEUE'] : 'mq-discover'

config = {
  :jolokiaHost       => jolokiaHost,
  :jolokiaPort       => jolokiaPort,
  :beanstalkHost     => beanstalkHost,
  :beanstalkPort     => beanstalkPort,
  :beanstalkQueue    => beanstalkQueue,
  :serviceConfigFile => serviceConfigFile
}

# ---------------------------------------------------------------------------------------

sd = ServiceDiscovery.new( config )
sd.queue()


## threads = Array.new()
##
##
## threads << Thread.new {
##
##   @data = sd.queue()
## }
##
## threads.each {|t| t.join }
##
# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }
#
# until stop
#   # do your thing
#   e.run()
#   sleep( interval.to_i )
# end

# -----------------------------------------------------------------------------

# EOF
