#!/usr/bin/ruby


require_relative 'storage'

# -----------------------------------------------------------------------------

ip    = '10.2.19.241'
short = 'master-17-tomcat'
long  = 'master-17-tomcat.coremedia.vm'

config   = { "ports": [200,400], "services": [ "cae-live", "rls" ] }
config_1 = { "ports": [200,400] }
config_2 = { "services": [ "cae-live", "rls" ] }


dns      = { :ip => ip, :short => short, :long => long }
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


r = Storage::RedisClient.new( { :redis => { :host => 'localhost' } } )

# puts r.delete( 'node' )
# puts r.get( 'node' )

puts '============================================================'

# puts 'dns: '
# # r.createDNS( dns )
# # r.createDNS( { :ip => '127.0.1.1', :short => "foo-bar", :long => "foo-bar.tld" } )
# puts r.dnsData( dns )
#
# puts ''
# puts 'status:'
# puts '  - read'
# puts r.status( { :short => short } )
#
# puts '  - set'
# r.setStatus( { :short => short, :status => 1 } )
# puts '  - get'
# puts r.status( { :short => short } )


puts ''
puts 'nodes: '
puts '  - read'
puts " - #{r.nodes()}"
puts " - #{r.nodes( { :short => short } )}"
puts " - #{r.nodes( { :status => 99 } )}"
puts " - #{r.nodes( { :status => 1 } )}"
puts '--------'

puts '  - create'
puts " - #{r.addNode( { :short => short })}"
puts '--------'
puts '  - read'
puts " - #{r.nodes()}"
puts '--------'
puts ''
# puts '  - remove'
# puts " - #{r.removeNode( { :short => short } )}"
# puts '--------'
# puts '  - read'
# puts " - #{r.nodes()}"
puts '--------'
puts '---------------------------------------------------------'

# puts ''
# puts 'config:'
# puts '  - delete'
# r.removeConfig( config )

# puts '  - create'
# r.createConfig( config )
# r.createConfig( config_1, true )
# r.createConfig( config_2, true )
# r.createConfig( { :short => short, :data => { "named": "rubbel-katz" } }, true )

# puts '  - read'
# puts r.config( { :short => short } )
# puts r.config( { :short => short, :key => 'ports' } )
# puts r.config( { :short => short, :key => 'services' } )
# puts r.config( { :short => short, :key => 'named' } )

# puts '  - delete'
# # r.removeConfig( { :short => short, :key => 'named' } )
# r.removeConfig( { :short => short, :key => 'ports' } )
# puts r.config( { :short => short } )


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

