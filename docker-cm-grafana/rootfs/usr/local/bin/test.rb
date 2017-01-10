#!/usr/bin/ruby


require_relative '../lib/grafana'



options = { "debug" => false, "timeout" => 3, "ssl" => true, :url_path => '/grafana' }
g = Grafana::Client.new( { :host => 'sg.xanhaem.de', :port => 443, :user => 'admin', :password => 'admin', :settings => options } )
