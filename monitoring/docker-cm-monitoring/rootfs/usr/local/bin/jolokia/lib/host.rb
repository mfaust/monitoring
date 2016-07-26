#!/usr/bin/ruby

require 'sqlite3'
require 'socket'
require 'timeout'
require 'logger'
require 'json'

# -------------------------------------------------------------------------------------------------------------------

class Discover

  def initialize

#    file = File.open( '/tmp/monitor.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @tmp_dir     = '/var/cache/monitoring'
    Dir.mkdir( @tmp_dir ) unless File.exist?( @tmp_dir )

    @jolokiaHost = 'localhost'
    @jolokiaPort = 8080

    @information = Hash.new()

  end

  # check if Node exists (simple ping)
  # result @bool
  def isRunning? ( ip )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

      @log.info( sprintf( '  node %-13s are available', ip.to_s ) )
      return true
    else
      @log.info( sprintf( '  node %-13s are NOT available', ip.to_s ) )
      return false
    end

  end

  def port_open? ( ip, port, seconds = 1 )
    # => checks if a port is open or not on a remote host
    Timeout::timeout( seconds ) do
      begin
        TCPSocket.new( ip, port ).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        false
      end
    end
    rescue Timeout::Error
      false

  end


  def discoverApplication( host, port )

    @log.debug( sprintf( 'check port %s for service ', port.to_s  ) )

    service = ''

    if( port == 3306 or port == 5432 or port == 28017 )

      case port
      when 3306
        service = 'mysql'
      when 5432
        service = 'postgres'
      when 28017
        service = 'mongodb'
      end
    else

      require 'net/http'
      require 'json'
      require 'uri'

      uri          = URI.parse( sprintf( 'http://%s:%s', @jolokiaHost, @jolokiaPort ) )
      http         = Net::HTTP.new( uri.host, uri.port )

      request      = Net::HTTP::Post.new( '/jolokia/' )
      request.add_field('Content-Type', 'application/json')

      # send hash above

      # hash for the NEW Port-Schema
      hash = {
        :type => "read",
        :mbean => "java.lang:type=Runtime",
        :attribute => [
          "ClassPath"
        ],
        :target => {
          :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
        }
      }
      request.body = JSON.generate( hash )

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        case error
        when Errno::ECONNREFUSED
          @log.error( 'connection refused' )
        when Errno::ECONNRESET
          @log.error( 'connection reset' )
        end
      else

        body         = JSON.parse( response.body )

        if( body['status'] == 200 )

          classPath  = body['value']['ClassPath'] ? body['value']['ClassPath'] : nil

          if( classPath.include?( 'cm7-tomcat-installation' ) )

            @log.debug( 'old style' )

            hash = {
              :type => "read",
              :mbean => "Catalina:type=Engine",
              :attribute => [
                'baseDir'
              ],
              :target => {
                :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
              }
            }

            request.body = JSON.generate( hash )
            response     = http.request( request )
            body         = JSON.parse( response.body )

            if( body['status'] == 200 )

              baseDir   = body['value']['baseDir'] ? body['value']['baseDir'] : nil

              regex = /
                ^                           # Starting at the front of the string
                (.*)                        #
                \/cm7-                      #
                (?<service>.+[a-zA-Z0-9-])  #
                (.*)-tomcat                 #
                $
              /x

              parts           = baseDir.match( regex )
            end

          else

            regex = /
              ^                           # Starting at the front of the string
              (.*)                        #
              \/coremedia\/               #
              (?<service>.+[a-zA-Z0-9-])  #
              \/current                   #
              (.*)                        #
              $
            /x

            parts           = classPath.match( regex )
          end

          if( parts )
            service         = "#{parts['service']}".strip.tr( '. ', '' )

            @log.debug( sprintf( '  => %s', service ) )
          else
            @log.error( 'unknown' )
          end

        else
          # uups
        end

      end

      # normalize service names
      case service
      when 'cms'
        service = 'content-management-server'
      when 'mls'
        service = 'master-live-server'
      when 'rls'
        service = 'repication-live-server'
      when 'wfs'
        service = 'workflow-server'
      when 'delivery'
        service = 'cae-live-1'
      end

    end

    # services.merge!( { name => { 'port' => p } } )

    return service
  end


  def run( host = nil, ports = [] )

    services = Hash.new()

    open = false

    ports.each do |p|

      if port_open?( host, p )
#         @log.info( "[OPEN]: Port #{p} is open on host #{host}" )
        open = true
      else
#         @log.debug( "[NOT OPEN]: Port #{p} is not open on host #{host}" )
        open = false
      end

      if( open == true )

        name = self.discoverApplication( host, p )

        services.merge!( { name => { 'port' => p } } )

      end

    end

    @information = { host => 'services' => { services } }

    @log.info( JSON.pretty_generate( @information ) )
  end

end

