#!/usr/bin/ruby
#
#
#
#



# require 'sqlite3'
# require 'socket'
# require 'timeout'
require 'logger'
require 'json'
require 'fileutils'

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

    @known_ports = [
      3306,     # mysql
      5432,     # postrgres
      28017,    # mongodb
      38099,
      40099,
      40199,
      40299,
      40399,
      40499,
      40599,
      40699,
      40799,
      40899,
      40999,
      41099,
      41199,
      41299,
      41399,
      42099,
      42199,
      42299,
      42399,
      42499,
      42599,
      42699,
      42799,
      42899,
      42999,
      43099,
      44099,
      45099
    ]

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

  # delete the directory with all files inside
  def deleteHost( host )

    dir_path  = sprintf( '%s/%s', @tmp_dir, host )

    if( File.exist?( dir_path ) )
      FileUtils.rm_r( dir_path )
    end

    return { 'status' => '200', 'message' => 'Host successful removed' }
  end

  # add Host and discovery applications
  def addHost( host, ports = [], force = false )

    # force delete
    if( force == true )
      self.deleteHost( host )
    end

    dir_path  = sprintf( '%s/%s', @tmp_dir, host )
    file_name = 'discovery.json'

    if( !File.exist?( dir_path ) )
      Dir.mkdir( dir_path )
    end

    # our default known ports
    if( ports.empty? )
      ports = @known_ports
    end

    if( File.exist?( sprintf( '%s/%s', dir_path, file_name ) ) == true )
      return { 'status' => '409', 'message' => 'Host already created' }
    end

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = port_open?( host, p )

      if( open == true )

        name = self.discoverApplication( host, p )

        services.merge!( { name => { 'port' => p } } )

      end

    end

    discover = JSON.pretty_generate( { host => { 'services' => services } } )

    File.open( sprintf( '%s/%s', dir_path, file_name ) , 'w' ) {|f| f.write( discover ) }

    return { 'status' => '201', 'message' => 'Host successful created' }
  end


  def listHosts( host = nil )

    hosts = Array.new()

    if( host == nil )

      Dir.chdir( @tmp_dir )
      Dir.glob( "**" ) do |f|

        if( FileTest.directory?( f ) )
          hosts.push( File.basename( f ) )
        end
      end

      hosts.sort!
      return { 'status' => 200, 'hosts' => hosts }

    else

      dir_path  = sprintf( '%s/%s', @tmp_dir, host )
      file_name = 'discovery.json'

      if( File.exist?( sprintf( '%s/%s', dir_path, file_name ) ) == true )

        file = File.read( sprintf( '%s/%s', dir_path, file_name ) )

        return JSON.parse( file )
      else

        return { 'status' => 404, 'message' => 'No discovery File found' }
      end

    end
  end

end

