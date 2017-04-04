#!/usr/bin/ruby


require_relative 'storage'

# -----------------------------------------------------------------------------

ip    = '127.0.0.10'
short = 'foo-bar'
long  = 'foo-bar.tld'

config  = { "ports": [200,400], "services": [ "cae-live", "rls" ] }

dns   = { :ip => ip, :short => short, :long => long }
config   = { :ip => ip, :short => short, :data => config }


d = Storage::Database.new( { :cacheDirectory => '/tmp' } )
d.createDNS( dns )
d.createConfig( config )
#d.removeConfig( { :ip => ip, :short => short, :key => 'ports' } )

puts d.dnsData( dns )
puts d.config( { :ip => ip, :key => 'ports' } )


puts '============================================================'

r = Storage::RedisClient.new( { :redis => { :host => 'localhost' } } )
r.createDNS( dns )
r.createConfig( config )
#r.removeConfig( { :ip => ip, :short => short, :key => 'ports' } )

puts r.dnsData( dns )
puts r.config( { :ip => ip, :short => short, :key => 'ports' } )

puts r.discoveryData( { :ip => ip, :short => short } )
# -----------------------------------------------------------------------------

