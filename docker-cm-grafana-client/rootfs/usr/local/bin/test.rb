#!/usr/bin/ruby


require_relative '../lib/grafana'

grafanaHost  = ENV['GRAFANA_HOST']   ? ENV['GRAFANA_HOST']  : 'localhost'
grafanaPort  = ENV['GRAFANA_PORT']   ? ENV['GRAFANA_PORT']  : 80
memcacheHost = ENV['MEMCACHE_HOST']  ? ENV['MEMCACHE_HOST'] : 'localhost'
memcachePort = ENV['MEMCACHE_PORT']  ? ENV['MEMCACHE_PORT'] : 11211

config = {
  :host              => grafanaHost,
  :port              => grafanaPort,
  :user              => 'admin',
  :password          => 'admin',
  :debug             => false,
  :timeout           => 10,
  :ssl               => false,
  :url_path          => '/grafana',
  :templateDirectory => '/usr/local/share/templates/grafana',
  :memcacheHost      => memcacheHost,
  :memcachePort      => memcachePort
}

g = Grafana::Client.new( config )

if( g != nil )

#   puts g.allUsers()
#   puts g.homeDashboard()

  g.createDashboardForHost( { :host => 'monitoring-16-01', :overview => true } )
#  g.deleteDashboards( { :host => 'monitoring-16-01' } )

end


