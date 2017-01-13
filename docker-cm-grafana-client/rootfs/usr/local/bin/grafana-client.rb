#!/usr/bin/ruby
#
# 13.01.2017 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require_relative '../lib/grafana'

# -----------------------------------------------------------------------------

grafanaHost         = ENV['GRAFANA_HOST']          ? ENV['GRAFANA_HOST']          : 'localhost'
grafanaPort         = ENV['GRAFANA_PORT']          ? ENV['GRAFANA_PORT']          : 80
grafanaUrlPath      = ENV['GRAFANA_URL_PATH']      ? ENV['GRAFANA_URL_PATH']      : '/grafana'
grafanaApiUser      = ENV['GRAFANA_API_USER']      ? ENV['GRAFANA_API_USER']      : 'admin'
grafanaApiPassword  = ENV['GRAFANA_API_PASSWORD']  ? ENV['GRAFANA_API_PASSWORD']  : 'admin'
grafanaTemplatePath = ENV['GRAFANA_TEMPLATE_PATH'] ? ENV['GRAFANA_TEMPLATE_PATH'] : '/usr/local/share/templates/grafana'
memcacheHost        = ENV['MEMCACHE_HOST']         ? ENV['MEMCACHE_HOST']         : 'localhost'
memcachePort        = ENV['MEMCACHE_PORT']         ? ENV['MEMCACHE_PORT']         : 11211
mqHost              = ENV['MQ_HOST']               ? ENV['MQ_HOST']               : 'localhost'
mqPort              = ENV['MQ_PORT']               ? ENV['MQ_PORT']               : 11300
mqQueue             = ENV['MQ_QUEUE']              ? ENV['MQ_QUEUE']              : 'mq-grafana'

config = {
  :host              => grafanaHost,
  :port              => grafanaPort,
  :user              => grafanaApiUser,
  :password          => grafanaApiPassword,
  :debug             => false,
  :timeout           => 10,
  :ssl               => false,
  :url_path          => grafanaUrlPath,
  :templateDirectory => grafanaTemplatePath,
  :memcacheHost      => memcacheHost,
  :memcachePort      => memcachePort,
  :mqHost            => mqHost,
  :mqPort            => mqPort,
  :mqQueue           => mqQueue
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

g = Grafana::Client.new( config )

if( g != nil )

  until stop
    g.queue()
    sleep( 5 )
  end

else
  exit 2
end

# -----------------------------------------------------------------------------

# EOF
