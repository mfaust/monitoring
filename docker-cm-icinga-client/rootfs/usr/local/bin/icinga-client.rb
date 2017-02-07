#!/usr/bin/ruby
#
# 03.01.2017 - Bodo Schulz
#
#
# v0.7.0

# -----------------------------------------------------------------------------

require_relative '../lib/icinga'

# -----------------------------------------------------------------------------

icingaHost      = ENV['ICINGA_HOST']              ? ENV['ICINGA_HOST']              : 'localhost'
icingaApiPort   = ENV['ICINGA_API_PORT']          ? ENV['ICINGA_API_PORT']          : 5665
icingaApiUser   = ENV['ICINGA_API_USER']          ? ENV['ICINGA_API_USER']          : 'admin'
icingaApiPass   = ENV['ICINGA_API_PASSWORD']      ? ENV['ICINGA_API_PASSWORD']      : nil
icingaCluser    = ENV['ICINGA_CLUSTER']           ? ENV['ICINGA_CLUSTER']           : false
icingaSatellite = ENV['ICINGA_CLUSTER_SATELLITE'] ? ENV['ICINGA_CLUSTER_SATELLITE'] : nil
mqHost          = ENV['MQ_HOST']                  ? ENV['MQ_HOST']                  : 'localhost'
mqPort          = ENV['MQ_PORT']                  ? ENV['MQ_PORT']                  : 11300
mqQueue         = ENV['MQ_QUEUE']                 ? ENV['MQ_QUEUE']                 : 'mq-icinga'

config = {
  :icingaHost      => icingaHost,
  :icingaApiPort   => icingaApiPort,
  :icingaApiUser   => icingaApiUser,
  :icingaApiPass   => icingaApiPass,
  :icingaCluser    => icingaCluser,
  :icingaSatellite => icingaSatellite,
  :mqHost          => mqHost,
  :mqPort          => mqPort,
  :mqQueue         => mqQueue
}

# ---------------------------------------------------------------------------------------

i = Icinga::Client.new( config )

# ---------------------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

if( i != nil )

  until stop
    # do your thing
    i.queue()
    sleep( 15 )
  end

end

# -----------------------------------------------------------------------------

# EOF
