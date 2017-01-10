#!/usr/bin/ruby


require_relative '../lib/grafana'

grafanaHost        = ENV['GRAFANA_HOST'] ? ENV['GRAFANA_HOST'] : 'localhost'
grafanaPort        = ENV['GRAFANA_PORT'] ? ENV['GRAFANA_PORT'] : 80


options = { :debug => false, :timeout => 3, :ssl => false, :url_path => '/grafana' }
g = Grafana::Client.new(
  { :host => grafanaHost, :port => grafanaPort, :user => 'admin', :password => 'admin', :settings => options }
)


puts g.dataSources()
puts g.availableDataSourceTypes()
