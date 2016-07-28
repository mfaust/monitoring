#
#
#
#
#
#

require 'logger'
require 'json'



class JolokiaDataRaiser

  attr_reader :status, :message, :services

  def initialize

#    file = File.open( '/tmp/monitor.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @currentDirectory = File.expand_path( File.join( File.dirname( __FILE__ ) ) )
    @cacheDirectory   = '/var/cache/monitoring'

    @jolokiaHost = 'localhost'
    @jolokiaPort = 8080

    @appConfigFile  = ''
    @serviceConfigFile = ''

    @monitoredServer = Array.new()

  end


  def applicationConfig( applicationConfig )
    @appConfigFile  = File.expand_path( applicationConfig )
  end


  def serviceConfig( serviceConfig )
    @serviceConfigFile = File.expand_path( serviceConfig )
  end


  # return a array of all monitored server
  def monitoredServer()

    Dir.chdir( @cacheDirectory )
    Dir.glob( "**" ) do |f|

      if( FileTest.directory?( f ) )
        @monitoredServer.push( File.basename( f ) )
      end
    end

    @monitoredServer.sort!

  end

  # merge hashes of configured and discovered data
  def createHostConfig( data )

    data.each do |d,v|

      # merge data between discovered Services and our base configuration,
      # the dicovered ports are IMPORTANT
      if( @serviceConfig['services'][d] )
        data[d].merge!( @serviceConfig['services'][d] ) { |key, port| port }
      else
        @log.debug( sprintf( 'missing entry \'%s\'', d ) )
      end
    end

    return data

  end


  def mergeSolrCores( metrics, cores = [] )

    work = Array.new()

    cores.each do |core|

      metric = Marshal.load( Marshal.dump( metrics ) )

      metric.each do |m|
        mb = m['mbean']
        mb.sub!( '%CORE%', core )
      end

      work.push( metric )
    end

    work.flatten!

    return work
  end


  def mergeData( data = {} )

    metrics_tomcat       = @jolokiaApplications['tomcat']      # standard metrics for Tomcat

#    data.keys.sort! { |a,b| a <=> b }

    data.each do |d,v|

      application = v['application'] ? v['application'] : nil
      solr_cores  = v['cores']       ? v['cores']       : nil

      v['metrics']= []

      if( application )

        if( solr_cores != nil )
          v['metrics'].push( self.mergeSolrCores( @jolokiaApplications[application]['metrics'], solr_cores ) )
        end

        @jolokiaApplications[application]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

        v['metrics'].push( metrics_tomcat['metrics'] )
        v['metrics'].push( @jolokiaApplications[application]['metrics'] )
      end

      if( @jolokiaApplications[d] )
        v['metrics'].push( metrics_tomcat['metrics'] )
        v['metrics'].push( @jolokiaApplications[d]['metrics'] ).flatten!
      end

      v['metrics'].flatten!
    end

    return data
  end


  # create an bulkset over all checks
  def createBulkCheck( host, data )

    metrics = {}

    if( data.count != 0 )

      result  = Array.new()
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




  def run( applicationConfig = nil, serviceConfig = nil )

    if( applicationConfig != nil )
      self.applicationConfig( applicationConfig )
    end

    if( serviceConfig != nil )
      self.serviceConfig( serviceConfig )
    end

    # read Application Configuration
    # they define all standard checks
    begin

      if( File.exist?( @appConfigFile ) )

        @config      = JSON.parse( File.read( @appConfigFile ) )

        if( @config['jolokia']['applications'] != nil )
          @jolokiaApplications = @config['jolokia']['applications']
        end

      else
        @log.error( sprintf( 'Application Config File %s not found!', @appConfigFile ) )
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

      if( File.exist?( @serviceConfigFile ) )
        @serviceConfig      = JSON.parse( File.read( @serviceConfigFile ) )
      else
        @log.error( sprintf( 'Config File %s not found!', @serviceConfigFile ) )
        exit 1
      end

    rescue JSON::ParserError => e

      @log.error( 'wrong result (no json)')
      @log.error( e )
      exit 1
    end

    # ----------------------------------------------------------------------------------------

    self.monitoredServer()

    file_name = 'discovery.json'
    save_file = 'mergedHostData.json'

    data = Hash.new()

    @monitoredServer.each do |h|

      dir_path  = sprintf( '%s/%s', @cacheDirectory, h )

      file = sprintf( '%s/%s', dir_path, file_name )

      if( File.exist?( file ) == true )

        @log.debug( file )

        data = JSON.parse( File.read( file ) )

        d = self.createHostConfig( data )
        d = self.mergeData( d )

        merged = JSON.pretty_generate( d )

        File.open( sprintf( '%s/%s', dir_path, save_file ) , 'w' ) {|f| f.write( merged ) }

        createBulkCheck( h, d )

#         @log.debug( JSON.pretty_generate( d ) )
      end
    end


#    json = JSON.pretty_generate( data )
#    File.open( sprintf( '%s/%s', dir_path, file_name ) , 'w' ) {|f| f.write( metricsResult ) }

#    createBulkCheck( host, port, data )

  end

end
