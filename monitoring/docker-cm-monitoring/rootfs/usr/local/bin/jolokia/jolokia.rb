#
# lib/jolokiaclient.rb

# ----------------------------------------------------------------------------

require 'logger'
require 'net/http'
require 'json'
require 'uri'

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

        @log.debug( sprintf( "    - with %s services", service_count ) )

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

        metrics = self.mergeChecks( host, k )

#         @log.debug( JSON.pretty_generate( metrics ) )
        mergedMetrics = self.jolokiaCreateBulkCheck( host, port, metrics )


        self.jolkiaSendChecks( mergedMetrics )

      end

    end

  end

  # merge checks between aap_config_file and services
  def mergeChecks( host, services )

#     @log.debug( sprintf( "      configured checks for Service %s on Host %s", services, host ) )
#     @log.debug()

    result = []

    service     = @jolokiaHost[host]['services'][services]
    desc        = service['description'] ? service['description'] : services
    application = service['application'] ? service['application'] : nil
    metrics     = service['metrics']     ? service['metrics']     : []

#     @log.debug( sprintf( "      %s", desc ) )
#     @log.debug( sprintf( "        app   : %s", application ) )
#     @log.debug( sprintf( "        metric: %s", metrics ) )

    app_1 = @jolokiaApplications[application]
    app_2 = @jolokiaApplications[services]

#     met_1 = nil

    metric_1 = []
#     metric_2 = []
#     met      = nil

    if( application )
      # aplication is set
      if( app_1 )
        metric_1 = app_1['metrics'] ? app_1['metrics'] : nil
      else
        metric_1 = []
      end
    else
      # application is NOT set
      if( app_2 )
        metric_1 = app_2['metrics'] ? app_2['metrics'] : nil
      else
        metric_1 = []
      end
    end

#     if( metrics )
      # aplication is set
#       metric_2 = metrics
#     end

    result.concat( metric_1.concat( metrics ) )

#     @log.debug( sprintf( "        =   metric 1: %s", metric_1 ) )
#     @log.debug( sprintf( "        =   metric 2: %s", metrics ) )
#     @log.debug( sprintf( "        =   metric 3: %s", result ) )

#     @log.debug()

#     @log.debug( sprintf( " =   result: %s", result ) )

    return result

  end


  def jolkiaSendChecks( metrics )

#     @log.debug( sprintf( "    jolkiaSendChecks()" ) )
#     @log.debug( JSON.pretty_generate( metrics ) )

    serverUrl = sprintf( "http://%s:%s/jolokia", @jolokiaProxyServer, @jolokiaProxyPort )

    uri          = URI.parse( serverUrl )
    http         = Net::HTTP.new( uri.host, uri.port )

    if( ! port_open?( @jolokiaProxyServer, @jolokiaProxyPort ) )
      @log.error( sprintf( "The Port %s on Host %s ist not open!", @jolokiaProxyPort, @jolokiaProxyServer ) )
      @log.error( "skip check" )
    else

#       @log.info( sprintf( "check  Service %s on Host %s:%s", k, host, port ) )
#       self.jolokiaBulkCheck( host, port, k, metric )

      request = Net::HTTP::Post.new(
        uri.request_uri,
        initheader = {'Content-Type' =>'application/json'}
      )

      #        request.set_form_data( metrics )
      request.body = metrics.to_json

      response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https" ) do |http|
        http.request(request)
      end

      @log.debug( JSON.pretty_generate( JSON.parse( response.body ) ) )
    end

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
  def jolokiaCreateBulkCheck( host, port, metrics )

    if( metrics.count != 0 )

      result = Hash.new()

      metrics.each do |m|

        if( m )

        m[:type] = 'read'
        m[:target] = {
          :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
        }
        end
      end

    end

    return metrics

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

j.jolokiaProxy
j.jolokiaHosts

#j.jolokiaService
#j.runChecks

