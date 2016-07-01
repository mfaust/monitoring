#
# lib/jolokiaclient.rb

# ----------------------------------------------------------------------------

require 'logger'
require 'net/http'
require 'json'
require 'uri'

# ----------------------------------------------------------------------------

class JolokiaClient

  def initialize( config_file )

#    file = File.open( '/tmp/jolokia-client.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @jolokiaProxyServer     = nil
    @jolokiaProxyPort       = nil
    @jolokiaStandardMetrics = nil

    config_file = File.expand_path( config_file )

    begin

      if( File.exist?( config_file ) )

        file = File.read( config_file )

        @config      = JSON.parse( file )

        if( @config['jolokia']['proxy'] != nil )

          @jolokiaProxyServer = @config['jolokia']['proxy']['server']
          @jolokiaProxyPort   = @config['jolokia']['proxy']['port']
        end

        if( @config['jolokia']['service']['tomcat']['metrics'] != nil )

          @jolokiaStandardMetrics = @config['jolokia']['service']['tomcat']['metrics']
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

    if( @jolokiaProxyServer != nil )

      @log.debug( sprintf( "configured Jolokia Proxy: %s  Port: %s", @jolokiaProxyServer, @jolokiaProxyPort ) )
    end
  end

  # list all Service Configuration
  def jolokiaService

    if( @config['jolokia']['service'] != nil )

      @log.debug( sprintf( "configured services" ) )

      service = @config['jolokia']['service'].each do |k,v|

        desc = v['description']
        port = v['port']
        host = v['host']
        metrics = v['metrics']

        @log.debug( sprintf( "  %s   %s", k, desc ) )

        if( ! port.empty?  )
          @log.debug( sprintf( "    Port: %s", port ) )
        end

      end

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
  def jolokiaBulkCheck( host, port, check, metrics )

    if( ! check.empty? )

      if( metrics.count != 0 )

        array = Array.new()
        result = Hash.new()

#         @log.debug( metrics )

        metrics.each do |m|

          if( m )

#             @log.debug( m )

          m[:type] = 'read'
          m[:target] = {
            :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
          }
          end
        end

        serverUrl = sprintf( "http://%s:%s/jolokia", @jolokiaProxyServer, @jolokiaProxyPort )

        uri          = URI.parse( serverUrl )
        http         = Net::HTTP.new( uri.host, uri.port )

        request = Net::HTTP::Post.new(
          uri.request_uri,
          initheader = {'Content-Type' =>'application/json'}
        )

        #        request.set_form_data( metrics )
        request.body = metrics.to_json

        response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https" ) do |http|
          http.request(request)
        end

#         @log.debug( JSON.pretty_generate( JSON.parse( response.body ) ) )

      end

    end

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



j = JolokiaClient.new( 'config/jolokia.json' )

j.jolokiaProxy
j.jolokiaService
j.runChecks

