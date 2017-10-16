#!/usr/bin/env ruby

require_relative 'lib/cm_grafana'

grafanaHost         = ENV.fetch('GRAFANA_HOST'           , 'grafana')
grafanaPort         = ENV.fetch('GRAFANA_PORT'           , 80)
grafanaUrlPath      = ENV.fetch('GRAFANA_URL_PATH'       , '/grafana')
grafanaApiUser      = ENV.fetch('GRAFANA_API_USER'       , 'admin')
grafanaApiPassword  = ENV.fetch('GRAFANA_API_PASSWORD'   , 'admin')

config_file         = ENV.fetch('CONFIG_FILE'            , nil )

config = {
  :grafana => {
    :host              => grafanaHost,
    :port              => grafanaPort,
    :user              => grafanaApiUser,
    :password          => grafanaApiPassword,
    :url_path          => grafanaUrlPath,
    :timeout           => 10,
    :ssl               => false
  }
}

g = CMGrafana.new( config )

# puts g.methods
# puts g.instance_methods


puts g.configure_server( config_file: './grafana_config.yml' )

