#!/usr/bin/ruby
#
# 13.01.2017 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

require 'rufus-scheduler'

require_relative '../lib/grafana'

# -----------------------------------------------------------------------------

grafanaHost         = ENV.fetch('GRAFANA_HOST','localhost')
grafanaPort         = ENV.fetch('GRAFANA_PORT',80)
grafanaUrlPath      = ENV.fetch('GRAFANA_URL_PATH','/grafana')
grafanaApiUser      = ENV.fetch('GRAFANA_API_USER','admin')
grafanaApiPassword  = ENV.fetch('GRAFANA_API_PASSWORD','admin')
grafanaTemplatePath = ENV.fetch('GRAFANA_TEMPLATE_PATH','/usr/local/share/templates/grafana')
memcacheHost        = ENV.fetch('MEMCACHE_HOST','localhost')
memcachePort        = ENV.fetch('MEMCACHE_PORT',11211)
mqHost              = ENV.fetch('MQ_HOST', 'localhost')
mqPort              = ENV.fetch('MQ_PORT', 11300)
mqQueue             = ENV.fetch('MQ_QUEUE', 'mq-grafana')
interval            = 10

config = {
  :host              => grafanaHost,
  :port              => grafanaPort,
  :user              => grafanaApiUser,
  :password          => grafanaApiPassword,
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

scheduler = Rufus::Scheduler.new

scheduler.every( interval, :first_in => 5 ) do

   g.queue()

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
