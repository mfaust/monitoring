#!/usr/bin/env ruby


require_relative 'storage'

# -----------------------------------------------------------------------------

ip    = '10.2.19.241'
short = 'master-17-tomcat'
long  = 'master-17-tomcat.coremedia.vm'

config   = { "ports": [200,400], "services": [ "cae-live", "rls" ] }
config_1 = { "ports": [200,400] }
config_2 = { "services": [ "cae-live", "rls" ] }


dns      = { :ip => ip, :short => short, :fqdn => long }
config   = { :ip => ip, :short => short, :data => config }
config_1 = { :ip => ip, :short => short, :data => config_1 }
config_2 = { :ip => ip, :short => short, :data => config_2 }
#
# d = Storage::Database.new( { :cacheDirectory => '/tmp' } )
# d.createDNS( dns )
# d.createConfig( config )
# #d.removeConfig( { :ip => ip, :short => short, :key => 'ports' } )
#
# puts d.dnsData( dns )
# puts d.config( { :ip => ip, :key => 'ports' } )
#
# puts d.nodes( { :short => short } )
# puts d.nodes( { :status => 99 } )
# puts d.nodes( { :status => 1 } )
#


r = Storage::MySQL.new( {
  :mysql => {
    :host => '127.0.0.1',
    :user => 'root',
    :password => 'database.pass',
    :schema => 'test'
  }
} )

#puts r.delete( 'node' )
#puts r.get( 'node' )

puts '============================================================'

puts 'dns: '
puts '  - set'
r.createDNS( dns )
r.createDNS( { :ip => '127.0.1.1', :short => "foo-bar", :fqdn => "foo-bar.tld" } )

puts '  - read'
puts r.dnsData()
puts r.dnsData( dns )
puts r.dnsData( { :short => "foo-bar" } )

puts '  - remove'
puts r.removeDNS( { :short => "foo-bar" } )
puts r.dnsData( { :short => short } )
puts r.dnsData( { :short => "foo-bar" } )


puts ''
puts 'status:'
puts '  - read'
puts r.status( { :short => short } )

puts '  - set'
r.setStatus( { :short => short, :status => Storage::MySQL::ONLINE } )
puts '  - get'
puts r.status( { :short => short } )

puts ''
puts 'nodes: '
puts '  - read'
puts " - #{r.nodes()}"
puts " - #{r.nodes( { :ip => '127.0.1.1', :short => short } )}"
puts " - #{r.nodes( { :status => Storage::MySQL::DELETE } )}"
puts " - #{r.nodes( { :status => Storage::MySQL::ONLINE } )}"
puts " - #{r.nodes( { :short=>"master-17-tomcat", :status => Storage::MySQL::PREPARE } )}"
puts '--------'

# puts '  - create'
# puts " - #{r.addNode( { :short => short })}"
# puts '--------'
# puts '  - read'
# puts " - #{r.nodes()}"
# puts '--------'
# puts ''
# # puts '  - remove'
# # puts " - #{r.removeNode( { :short => short } )}"
# # puts '--------'
# # puts '  - read'
# # puts " - #{r.nodes()}"
# puts '--------'
# puts '---------------------------------------------------------'

puts ''
puts 'config:'
#puts '  - delete'
#r.removeConfig( { :ip => '127.0.10.10' } )
#r.removeConfig( config )

puts '  - create'
r.createConfig( config )
r.createConfig( config_1 )
r.createConfig( config_2 )
r.createConfig( { :short => short, :data => { "named": "rubbel-katz" } } )

puts '  - read'
puts r.config( { :short => short } )
puts r.config( { :short => short, :key => 'ports' } )
puts r.config( { :short => short, :key => 'services' } )
puts r.config( { :short => short, :key => 'named' } )

puts '  - delete'
r.removeConfig( { :short => short, :key => 'named' } )
r.removeConfig( { :short => short, :key => 'ports' } )
puts r.config( { :short => short } )


# puts ''
# puts 'discovery:'
# puts '  - read'
# puts r.discoveryData( { :short => short } )
# puts JSON.pretty_generate( r.discoveryData( { :short => short, :service => 'cae-live-1' } ) )
# puts r.discoveryData( { :short => short } ).keys.sort


# puts ''
# puts 'measurements:'
# puts '  - read'
# # puts r.measurements( { :short => short } )
# puts r.measurements( { :short => short, :application => 'cae-live-1' } )
#
#

# data = r.get( Storage::RedisClient.cacheKey( { :host => short, :pre => 'collector' } ) )

#data = eval(data)

#if( data.is_a?(String))
#  data = JSON.parse(data)
#end

# puts data
#
# cacheKey = Storage::RedisClient.cacheKey( { :host => short, :pre => 'result', :service => 'sitemanager' } )
#
# puts
#
# puts JSON.pretty_generate( r.get( cacheKey ) )


# -----------------------------------------------------------------------------

