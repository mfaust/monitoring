#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/icinga2'

# -----------------------------------------------------------------------------

logDirectory     = '/var/log/monitoring'

icinagHost      = ENV['ICINGA_HOST']         ? ENV['ICINGA_HOST']          : 'localhost'
icinagPort      = ENV['ICINGA_PORT']         ? ENV['ICINGA_PORT']          : 2003
icingaApiUser   = ENV['ICINGA_API_USER']     ? ENV['ICINGA_API_USER']      : 8081
icingaApiPass   = ENV['ICINGA_API_PASSWORD'] ? ENV['ICINGA_API_PASSWORD']  : nil
mqHost          = ENV['MQ_HOST']             ? ENV['MQ_HOST']              : 'localhost'
mqPort          = ENV['MQ_PORT']             ? ENV['MQ_PORT']              : 11300
mqQueue         = ENV['MQ_QUEUE']            ? ENV['MQ_QUEUE']             : 'mq-graphite'

config = {
  :logDirectory   => logDirectory,
  :icingaHost     => icingaHost,
  :icingaPort     => icingaPort,
  :icingaApiUser  => icingaApiUser
  :icingaApiPass  => icingaApiPass
  :mqHost         => mqHost,
  :mqPort         => mqPort,
  :mqQueue        => mqQueue
}

# ---------------------------------------------------------------------------------------

i = Icinga2::Client.new( config )

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
  i.queue()
  sleep( 5 )
end

# -----------------------------------------------------------------------------

# EOF
