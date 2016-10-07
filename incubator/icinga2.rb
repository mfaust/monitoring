#!/usr/bin/ruby

require 'rest-client'
require 'openssl'
require 'logger'
require 'json'
require 'net/http'
require 'uri'

require_relative '/home/bschulz/src/cm-xlabs/monitoring/docker-cm-monitoring/rootfs/usr/local/lib/icinga2.rb'

logDirectory     = '/tmp'

icingaHost       = 'localhost'
icingaPort       = 5665
icingaApiUser    = 'root'
icingaApiPass    = 'icinga'

icingaConfig = {
  'logDirectory'       => logDirectory,
  'icingaHost'         => icingaHost,
  'icingaPort'         => icingaPort,
  'icingaApiUser'      => icingaApiUser,
  'icingaApiPass'      => icingaApiPass
}

host = 'monitoring-16-01'

services = {
  'wfs-uapi-cache' => {
    'display_name' => "WFS UAPI Cache",
    'check_command' => 'coremedia_cache',
    'max_check_attempts' => 5,
    'host_name' => host,
    'vars.host' => host,
    'vars.application' => 'workflow-server',
    'vars.cache' => 'uapi-cache'
  },
  'http-preview-helios' => {
    'display_name'       => sprintf( 'preview-helios.%s', host ),
    'check_command'      => 'http',
    'max_check_attempts' => 5,
    'host_name'          => host,
    'vars.http_vhost'    => host,
    'vars.http_uri'      => sprintf( 'https://preview-helios.%s.coremedia.vm/perfectchef-de-de', host ) ,
    'vars.http_ssl'      => true
  }
}

icinga = Icinga2.new( icingaConfig )

puts icinga.listHost( host )

puts icinga.deleteHost( host )

puts icinga.addHost( host )

puts icinga.addServices( host, services )



#http.ca_file = <YOUR CA-CERT FILE PATH>
#http.verify_mode = OpenSSL::SSL::VERIFY_PEER
#http.verify_depth = 5

