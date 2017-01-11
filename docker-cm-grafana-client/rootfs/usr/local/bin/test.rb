#!/usr/bin/ruby


require_relative '../lib/grafana'

grafanaHost        = ENV['GRAFANA_HOST'] ? ENV['GRAFANA_HOST'] : 'localhost'
grafanaPort        = ENV['GRAFANA_PORT'] ? ENV['GRAFANA_PORT'] : 80


config = {
  :host => grafanaHost,
  :port => grafanaPort,
  :user => 'admin',
  :password => 'admin',
  :debug    => true,
  :timeout  => 10,
  :ssl      => false,
  :url_path => '/grafana',
  :templateDirectory => '/usr/local/share/templates/grafana'
}

g = Grafana::Client.new( config )

if( g != nil )

#   puts g.allUsers()
#   puts g.homeDashboard()

  puts g.createDashboardForHost( { :host => 'monitoring-16-01' } )
end


