#
#
#

require 'timeout'
require 'socket'


def isIp?( data )

  require "ipaddress"

  return IPAddress.valid?( data ) # "192.128.0.12"
  #=> true

  # IPAddress.valid? "192.128.0.260"
  #=> false
end

#ValidIpAddressRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
#ValidHostnameRegex = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";

  # return a array of all monitored server
  def monitoredServer( cacheDirectory )

    server = Array.new()

    Dir.chdir( cacheDirectory )
    Dir.glob( "**" ) do |f|

      if( FileTest.directory?( f ) )
        server.push( File.basename( f ) )
      end
    end

    server.sort!

    return server
  end



  # check if Node exists (simple ping)
  # result @bool
  def isRunning? ( ip )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

      @log.info( sprintf( 'node %-13s is available', ip.to_s ) )
      return true
    else
      @log.info( sprintf( 'node %-13s is NOT available', ip.to_s ) )
      return false
    end

  end


  def dnsResolve( name )

    require 'resolve/hostname'

    begin
      r  = Resolve::Hostname.new( :ttl => 320, :resolver_ttl => 120 )
      ip = r.getaddress( name )
    rescue => e
      @log.debug( e )
      return Socket.gethostbyname(name).first
    end

    @log.debug( sprintf( ' => found IP :\'%s\'', ip ) )

    return ip
  end


  def portOpen? ( ip, port, seconds = 1 )

    begin
      r  = Resolve::Hostname.new( :ttl => 320, :resolver_ttl => 120 )
      ip = r.getaddress( ip )
    rescue => e
      @log.debug( e )
      return false
    end

    # => checks if a port is open or not on a remote host
    Timeout::timeout( seconds ) do
      begin
        TCPSocket.new( ip, port ).close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        @log.error( e )
        return false
      end
    end
    rescue Timeout::Error => e
      @log.error( e )
      return false
  end


  # check if Node exists (simple ping)
  # result @bool
#   def isRunning? ( ip )
#
#     @log.debug( sprintf( "check host '%s'" , ip ) )
#
#     fqdn = []
#
#     begin
#       timeout(5) do
#         begin
#           fqdn = Socket.gethostbyname( ip )
#         rescue SocketError => e
#           @log.error( e )
#           return false
#         end
#       end
#     rescue Timeout::Error
#       @log.error( 'Timed out!' )
#       return false
#     end
#     @log.debug( sprintf( '  FQDN \'%s\'', fqdn.first ) )
#
#     # first, ping check
#     if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )
#
#       @log.info( sprintf( 'node %-15s are available', ip.to_s ) )
#       return true
#     else
#       @log.info( sprintf( 'node %-15s are NOT available', ip.to_s ) )
#       return false
#     end
#
#   end
#
#   def port_open? ( ip, port, seconds = 1 )
#     # => checks if a port is open or not on a remote host
#     begin
#       timeout( seconds ) do
#         begin
#           TCPSocket.new( ip, port ).close
#           true
#         rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
#           false
#         end
#       end
#     rescue Timeout::Error
#       false
#     end
#
#     @log.debug( '' )
#
#   end

