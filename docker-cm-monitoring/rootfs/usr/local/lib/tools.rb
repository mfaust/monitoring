#
#
#

require 'json'
require 'timeout'
require 'socket'


def isIp?( data )

  require "ipaddress"

  return IPAddress.valid?( data ) # "192.128.0.12"
  #=> true

  # IPAddress.valid? "192.128.0.260"
  #=> false
end

def validJson?( json )
  begin
    JSON.parse( json )
    return true
  rescue JSON::ParserError => e
    @log.info("Json parse error: #{e}")
    return false
  end
end

def regenerateGrafanaTemplateIDs( json )

  if( validJson?( json ) )

    tpl = JSON.parse( json )

    rows = ( tpl['dashboard'] && tpl['dashboard']['rows'] ) ? tpl['dashboard']['rows'] : nil

    if( rows != nil )

#      @log.debug( sprintf( ' => found %d rows', rows.count ) )

      counter = 1
      idCounter = 10
      rows.each_with_index do |r, counter|

#        @log.debug( sprintf( ' row  %d', counter ) )

        panel = r['panels'] ? r['panels'] : nil
#        @log.debug( sprintf( '   => with %d widgets', panel.count ) )

        panel.each do |p|
          p['id']   = idCounter
          idCounter = idCounter+1 # idCounter +=1 ??
        end
      end
    end

    return JSON.generate( tpl )
  else

    return false
  end

end


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

    @log.debug("Monitored server: #{server}")

    return server
  end



  # check if Node exists (simple ping)
  # result @bool
  def isRunning? ( ip )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

#       @log.info( sprintf( 'node %-13s is available', ip.to_s ) )
      return true
    else
#       @log.info( sprintf( 'node %-13s is NOT available', ip.to_s ) )
      return false
    end

  end


  def dnsResolve( name )

    require 'resolve/hostname'

    begin
      r  = Resolve::Hostname.new( :ttl => 320, :resolver_ttl => 120, :system_resolver => true )
      ip = r.getaddress( name )
    rescue => e
      @log.debug( e )
      ip = Socket.gethostbyname( name ).first
    end

    return ip
  end

def ip( host )

  begin
    ip = Socket.gethostbyname( host ).first
  rescue => e
    @log.debug( e )
    ip = host
  end

  return ip
end


def cacheKey( pre, host, v )

  ip = ip( host )

  return sprintf( '%s__%s__%s', pre, ip, v )

end



  def portOpen? ( name, port, seconds = 1 )

    ip = dnsResolve( name )

    # => checks if a port is open or not on a remote host
    Timeout::timeout( seconds ) do
      begin
        TCPSocket.new( ip, port ).close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
#         @log.error( e )
        return false
      end
    end
    rescue Timeout::Error => e
#       @log.error( e )
      return false
  end



def normalizeService( service )

  # normalize service names for grafana
  case service
    when 'content-management-server'
      service = 'CMS'
    when 'master-live-server'
      service = 'MLS'
    when 'replication-live-server'
      service = 'RLS'
    when 'workflow-server'
      service = 'WFS'
    when /^cae-live/
      service = 'CAE_LIVE'
    when /^cae-preview/
      service = 'CAE_PREV'
    when 'solr-master'
      service = 'SOLR_MASTER'
#    when 'solr-slave'
#      service = 'SOLR_SLAVE'
    when 'content-feeder'
      service = 'FEEDER_CONTENT'
    when 'caefeeder-live'
      service = 'FEEDER_LIVE'
    when 'caefeeder-preview'
      service = 'FEEDER_PREV'
  end

  return service.tr('-', '_').upcase

end



  # cae-live-1 -> cae-live
  def removePostfix( service )

    if( service =~ /\d/ )

      lastPart = service.split("-").last
      service  = service.chomp("-#{lastPart}")
#       @log.debug("Chomped service: #{service}")
    end

    return service

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

