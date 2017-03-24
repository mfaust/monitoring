#
#
#

require 'json'
require 'timeout'
require 'socket'


def isIp?( data )

  require "ipaddress"

  return IPAddress.valid?( data ) # "192.128.0.12"
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

      counter = 1
      idCounter = 10
      rows.each_with_index do |r, counter|

        panel = r['panels'] ? r['panels'] : nil
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

  return server
end


# return some Information about given Hostname
def hostResolve( host )

  require 'ipaddress'
  require 'open3'

  line = nil
  long  = nil
  short = nil
  ip    = nil

  if( IPAddress.valid?( host ) )

    cmd = sprintf( 'dig -x %s +short', host )

    Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

      returnValue = wait_thr.value
      stdOut      = stdout.gets
      stdErr      = stderr.gets

      if( returnValue == 0 && !stdOut.to_s.empty? )
        host = stdOut
      else

      end
    end
  end

  line  = nil

  cmd   = sprintf( 'host -t A %s', host )

  Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

    returnValue = wait_thr.value
    stdOut      = stdout.gets
    stdErr      = stderr.gets

    if( returnValue == 0 && !stdOut.to_s.empty? )
      line = stdOut
    else

    end
  end

  if( line != nil )

    parts = line.split( ' ' )

    long  = parts.first.strip
    ip    = parts.last.strip
    short = long.split('.').first

  end

  result = {
    :ip    => ip != nil ? ip : host,
    :short => short,
    :long  => long
  }

  return result

end


# check if Node exists (simple ping)
# result @bool
def isRunning? ( ip )

  # first, ping check
  if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )
    return true
  else
    return false
  end

end


def ip( host )

  begin
    ip = Socket.gethostbyname( host ).first
  rescue => e
    ip = host
  end

  return ip
end


def cacheKey( pre, host, v )

  ip = ip( host )

  return sprintf( '%s__%s__%s', pre, ip, v )

end



def portOpen? ( host, port, seconds = 1 )

  # => checks if a port is open or not on a remote host
  Timeout::timeout( seconds ) do
    begin
      TCPSocket.new( host, port ).close
      return true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      return false
    end
  end
  rescue Timeout::Error => e
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
  end

  return service

end

