#
# lib/jolokiaclient.rb

# ----------------------------------------------------------------------------

require 'logger'
require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

# ----------------------------------------------------------------------------

class JolokiaClient

  def initialize( app_config_file, config_file )

#    file = File.open( '/tmp/jolokia-client.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

#     @jolokiaProxyServer     = nil
#     @jolokiaProxyPort       = nil
#     @jolokiaStandardMetrics = nil

    app_config_file = File.expand_path( app_config_file )
    config_file     = File.expand_path( config_file )

    # read Application Configuration
    # they define all standard checks
    begin

      if( File.exist?( app_config_file ) )

        file = File.read( app_config_file )

        @config      = JSON.parse( file )

        if( @config['jolokia']['applications'] != nil )

          @jolokiaApplications = @config['jolokia']['applications']

        end

      else
        @log.error( sprintf( 'Application Config File %s not found!', app_config_file ) )
        exit 1
      end

    rescue JSON::ParserError => e

      @log.error( 'wrong result (no json)')
      @log.error( e )
      exit 1
    end

    # read host Configuration
    #
    begin

      if( File.exist?( config_file ) )

        file = File.read( config_file )

        @config      = JSON.parse( file )

        if( @config['jolokia']['proxy'] != nil )
          @jolokiaProxy = @config['jolokia']['proxy']

          @jolokiaProxyServer = @jolokiaProxy['server']
          @jolokiaProxyPort   = @jolokiaProxy['port']
        end

        if( @config['jolokia']['host'] != nil )
          @jolokiaHost = @config['jolokia']['host']
        end

      else
        @log.error( sprintf( 'Config File %s not found!', config_file ) )
        exit 1
      end

    rescue JSON::ParserError => e

      @log.error( 'wrong result (no json)')
      @log.error( e )
      exit 1
    end

  end

  # => checks if a port is open or not on a remote host
  def port_open? ( ip, port, seconds = 1 )

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

  # list a Proxy Configuration
  def jolokiaProxy

    if( @jolokiaProxy != nil )
      @log.debug( sprintf( "configured Jolokia Proxy: %s  Port: %s", @jolokiaProxyServer, @jolokiaProxyPort ) )
    end

  end

  # list all defines Hosts they we monitoring
  def jolokiaHosts

    if( @jolokiaHost != nil )

      @jolokiaHost.each do |h,d|

        @log.debug( sprintf( "  Host %s", h ) )

        service_count = d['services'] ? d['services'].count : 0

#         @log.debug( sprintf( "    - with %s services", service_count ) )

        self.jolokiaService( h )
      end

    end

  end

  # list all Service Configuration
  def jolokiaService( host )

    if( @jolokiaHost[host]['services'] != nil )

      service = @jolokiaHost[host]['services'].each do |k,v|

        desc = v['description']
        port = v['port']
        metrics = v['metrics']

        @log.debug( sprintf( "    %s   %s", k, desc ) )

        if( ! port.empty?  )
          @log.debug( sprintf( "      Port: %s", port ) )
        end

        metrics       = self.mergeChecks( host, k )
        mergedMetrics = self.jolokiaCreateBulkCheck( host, port, metrics )
        metricsResult = self.jolkiaSendChecks( mergedMetrics )

        self.saveResult( host, port, k, metricsResult )

      end

    end

  end

  # merge checks between aap_config_file and services
  def mergeChecks( host, services )

    result  = []

    service              = @jolokiaHost[host]['services'][services]
    desc                 = service['description'] ? service['description'] : services
    application          = service['application'] ? service['application'] : nil

    if( service['metrics'] != nil )

      metrics_inline     = { "description" => sprintf( "inline metrics for %s", services ), "metrics" => service['metrics'] }
    else
      metrics_inline     = {}
    end

    metrics_tomcat       = @jolokiaApplications['tomcat']      # standard metrics for Tomcat
    metrics_application  = @jolokiaApplications[application]   # metrics for the given 'application'  e.g. 'cae'
    metrics_service      = @jolokiaApplications[services]      # metrics for the giveb 'service-name' e.g. 'cae-preview'

    metric_1 = {}

    # priority:
    #   add metrics from tomcat
    #   1. metrics from application settings
    #   2. metrics from service name
    #   add metrics from inline
    if( application )
      # aplication is set =>  use metrics from application
      if( metrics_application )
        metric_1 = metrics_application
      end
    else
      # application is NOT set => use metrics from service
      if( metrics_service )
        metric_1 = metrics_service
      end
    end

    result.push( metrics_tomcat )
    if( metric_1 )
      result.push( metric_1 )
    end

    if( metrics_inline )
      result.push( metrics_inline )
    end

    return result

  end


  def jolkiaSendChecks( metrics )

    result       = nil
    serverUrl    = sprintf( "http://%s:%s/jolokia", @jolokiaProxyServer, @jolokiaProxyPort )

    uri          = URI.parse( serverUrl )
    http         = Net::HTTP.new( uri.host, uri.port )

    # if our jolokia proxy available?
    if( ! port_open?( @jolokiaProxyServer, @jolokiaProxyPort ) )
      @log.error( sprintf( "The Port %s on Host %s ist not open!", @jolokiaProxyPort, @jolokiaProxyServer ) )
      @log.error( "skip check" )
    else

      # "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
      course_line = /
        ^                   # Starting at the front of the string
        (.*):\/\/           # all after the douple slashes
        (?<host>.+\S)       # our hostname
        :                   # seperator between host and port
        (?<port>\d+)        # our port
      /x

      dest_uri  = metrics[0][:target][:url]
      parts     = dest_uri.match( course_line )
      dest_host = "#{parts['host']}".strip
      dest_port = "#{parts['port']}".strip

      # if our destination service (behind the jolokia proxy) available?
      if( ! port_open?( dest_host, dest_port ) )
        @log.error( sprintf( "      => The Port %s on Host %s ist not open!", dest_port, dest_host ) )
        @log.error( "      skip check" )
      else

        request = Net::HTTP::Post.new(
          uri.request_uri,
          initheader = {'Content-Type' =>'application/json'}
        )
        request.body = metrics.to_json

        response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https" ) do |http|
          http.request(request)
        end

        result = JSON.pretty_generate( JSON.parse( response.body ) )
      end
    end

    result = self.reorganizeData( result )

    return JSON.pretty_generate( result )

  end

  # reorganize data to later simple find
  def reorganizeData( data )

    if( data == nil )
      @log.error( "no data for reorganize" )
      return
    end

    data    = JSON.parse( data )
    result  = Array.new()

    course_line = /
      ^                   # Starting at the front of the string
      (.*)type=           #
      (?<type>.+\S)       #
      $
    /x

    data.each do |c|

      mbean      = c['request']['mbean']
      request    = c['request']
      value      = c['value']
      timestamp  = c['timestamp']
      status     = c['status']

      parts      = mbean.match( course_line )
      mbean_type = "#{parts['type']}".strip.tr('.', '')

      result.push(
        mbean_type.to_s => {
          'status' => status,
          'timestamp' => timestamp,
          'request' => request,
          'value'   => value
        }
      )

    end

    return result
  end


  #
  def saveResult( host, port, service, metricsResult )

#     @log.debug( sprintf( "      %s", host ) )
#     @log.debug( sprintf( "        port   : %s", port ) )
#     @log.debug( sprintf( "        k      : %s", service ) )
#     @log.debug( sprintf( "        result      : %s", metricsResult ) )

    dir_path  = sprintf( '/var/cache/monitoring/%s/%s', host, port )
    file_name = sprintf( '%s.json', service )

    FileUtils::mkdir_p( dir_path )

    File.open( sprintf( '%s/%s', dir_path, file_name ) , 'w' ) {|f| f.write( metricsResult ) }

  end

  # every check use an own request
  def jolokiaSingleCheck( host, port, check, metrics )

    serverUrl = sprintf( "http://%s:%s/jolokia", @jolokiaProxyServer, @jolokiaProxyPort )
    target = {
      :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
    }

    if( ! check.empty? )

      if( metrics.count != 0 )

        require 'jolokia'

        jolokia = Jolokia.new( url: serverUrl )

        metrics.each do |m|

          name      = m['name']
          mbean     = m['mbean']
          attribute = m['attribute']

          response = jolokia.request( :post,
            type: 'read',
            mbean: mbean,
            attribute: attribute,
            target: target
          )

          @log.debug(  JSON.pretty_generate( response ) )

        end
      end
    end

  end

  # create an bulkset over all checks
  def jolokiaCreateBulkCheck( host, port, data )

    metrics = {}

    if( data.count != 0 )

      result = Array.new()
      metrics = Hash.new()

      data.each do |m|

        if( m )

          metrics = m['metrics']

          if ( metrics )
            metrics.each do |m|

              m[:type] = 'read'
              m[:target] = {
                :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
              }
            end

            result.push( metrics ).flatten!
          end
        end
      end
    end

    return result

  end

  def runChecks

    if( @config['jolokia']['service'] != nil )

      @log.debug( sprintf( "configured services" ) )

      service = @config['jolokia']['service'].each do |k,v|

        port    = v['port']
        host    = v['host']
        metrics = v['metrics']

        # append the metric above with the standardMetrics
        metric = Array.new()
        metric.push( @jolokiaStandardMetrics ).push( metrics ).flatten!

        if( ! port.empty?  )
#          self.jolokiaSingleCheck( host, port, k, metric )
          if( port_open?( host, port ) )
            @log.info( sprintf( "check  Service %s on Host %s:%s", k, host, port ) )
            self.jolokiaBulkCheck( host, port, k, metric )
          else
            @log.error( sprintf( "The Port %s for Service %s on Host %s ist not open!", port, k, host ) )
            @log.error( "skip check" )
          end
        end
      end
    end

  end

end



j = JolokiaClient.new( 'config/application.json', 'config/jolokia.json' )

# j.jolokiaProxy
j.jolokiaHosts

#j.jolokiaService
#j.runChecks

