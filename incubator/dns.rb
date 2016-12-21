#!/usr/bin/ruby

require 'socket'
require 'uri'



def isIp?( data )

  require "ipaddress"

  return IPAddress.valid?( data ) # "192.128.0.12"
  #=> true

  # IPAddress.valid? "192.128.0.260"
  #=> false
end

def hostInformation( host )

  require "ipaddress"

  line = nil


    if( IPAddress.valid?( host ) )

    puts 'ip given'

    cmd = sprintf( 'dig -x %s +short', host )
 
    Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

      line = stdout.gets
    end

    host = line[0...-2]

  end

    require 'open3'
    
    cmd = sprintf( 'host %s', host )
    line = nil

    Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

#      puts "stdout is:" + stdout.read
#      puts "stderr is:" + stderr.read
      
      line = stdout.gets
    end

puts line

  if( line != nil )
    
#    line.gsub!( 'has address', '' )

    parts = line.split( ' ' )

    hostnameLong = parts.first.strip
    ip           = parts.last.strip
    hostnameShort= hostnameLong.split('.').first
 
#    puts hostnameLong.split('.').last(2).join('.')
#    puts URI.parse( hostnameLong ).host # .split('.', 2)[1]

  end

  return {
    :ip => ip,
    :short => hostnameShort, 
    :long  => hostnameLong
  }

#  puts hostnameLong
#  puts hostnameShort
#  puts ip
end

def dnsResolve( name )

    require 'resolve/hostname'

    begin
      puts 'use resolve.hostname'
      r  = Resolve::Hostname.new( :ttl => 60, :resolver_ttl => 20, :system_resolver => false )
      ip = r.getaddress( name )
    rescue => e
      puts 'fallback, use socket.gethostbyname'
      puts ( e )
      ip = Socket.gethostbyname( name ).first
    end

    return ip
end


puts hostInformation( 'monitoring-16-01' )

puts hostInformation( '10.2.10.211' )

# puts dnsResolve( 'monitoring-16-01' )

#hostInformation( ip )

