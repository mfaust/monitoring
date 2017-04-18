#!/usr/bin/ruby
#
# 13.01.2017 - Bodo Schulz
#
#
# v1.8.0

# -----------------------------------------------------------------------------

require 'json'
require 'socket'
require 'timeout'
require 'fileutils'
require 'time'
require 'date'
require 'time_difference'
require 'rufus-scheduler'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'monkey'
require_relative 'jolokia'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'external-clients'

# -----------------------------------------------------------------------------

module DataCollector

  class Config

    include Logging

    attr_accessor :config
    attr_accessor :jolokiaApplications

    def initialize( settings = {} )

      applicationConfig  = settings.dig( :configFiles, :application )
      serviceConfig      = settings.dig( :configFiles, :service )

      @config             = nil
      jolokiaApplications = nil

      appConfigFile  = File.expand_path( applicationConfig )

      begin

        if( File.exist?( appConfigFile ) )

          @config      = YAML.load_file( appConfigFile )

          @jolokiaApplications = @config.dig( 'jolokia', 'applications' )

        else
          logger.error( sprintf( 'Application Config File %s not found!', appConfigFile ) )

          raise( sprintf( 'Application Config File %s not found!', appConfigFile ) )

        end
      rescue => e

      end

    end

  end


  class Prepare

    include Logging

    def initialize( settings = {} )

      @redisHost         = settings.dig(:redis, :host)
      @redisPort         = settings.dig(:redis, :port) || 6379

      @cfg                = Config.new( settings )
      @redis              = Storage::RedisClient.new( { :redis => { :host => @redisHost } } )

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

    # merge Data between Property Files and discovered Services
    # creates mergedHostData.json for every Node
    def buildMergedData( params = {} )

      host = params.dig(:hostname)
      fqdn = params.dig(:fqdn)

#       logger.debug( params )

      if( host == nil )
        logger.error( 'no hostname found' )
        return {}
      end

      #
      tomcatApplication = Marshal.load( Marshal.dump( @cfg.jolokiaApplications ) )

      # Redis based
      data = @redis.discoveryData( { :short => host } )

      if( data == nil || data == false || data.count() == 0 )
        logger.error( 'no discovery in database data found' )
        return false
      end

      dataForRedis = Array.new()

      data.each do |service,payload|

        result      = self.mergeData( service.to_s, tomcatApplication, payload )

#         logger.debug( JSON.pretty_generate( result ) )

        dataForRedis << { service.to_s => result }
      end

      dataForRedis = dataForRedis.deep_string_keys

      # http://stackoverflow.com/questions/11856407/rails-mapping-array-of-hashes-onto-single-hash
      # mapping array of hashes onto single hash
      dataForRedis = dataForRedis.reduce( {} , :merge )

      @redis.createMeasurements( { :short => host, :data => dataForRedis } )

      return true

    end


    def mergeData( service, tomcatApplication, data = {} )

      metricsTomcat     = tomcatApplication.dig('tomcat')      # standard metrics for Tomcat

      configuredApplication = tomcatApplication.keys

#       logger.debug( '----------------------------------------------------------------------')
#       logger.debug( "look for service: '#{service}'" )
#       logger.debug( "configured Applications: #{configuredApplication}" )
#       logger.debug( data )

      dataSource = nil

      if( data == nil || data.count() == 0 )
        logger.debug( 'no data to merge' )

        return {}
      end

      if( data.dig(:data) == nil )

        application = data.dig('application')
        solr_cores  = data.dig('cores')
        metrics     = data.dig('metrics')

        dataSource  = 'redis'
      else

        application = data.dig(:data, 'application')
        solr_cores  = data.dig(:data, 'cores')
        metrics     = data.dig(:data, 'metrics')

        dataSource  = 'sqlite'
      end

# logger.debug( "data source: '#{dataSource}'" )
# logger.debug( "application: '#{application}'" )
# logger.debug( "solr_cores : '#{solr_cores}'" )
# logger.debug( "metrics    : '#{metrics}'" )
#       logger.debug( '----------------------------------------------------------------------')

      if( dataSource == 'redis' )

        data['metrics'] ||= []
      else

        data[:data]            ||= {}
        data[:data]['metrics'] ||= []
      end

#       logger.debug( data )

      if( configuredApplication.include?( service ) )

        logger.debug( "found #{service} in tomcat application" )

        if( dataSource == 'redis' )
          data['metrics'].push( metricsTomcat.dig('metrics') )
          data['metrics'].push( tomcatApplication.dig( service, 'metrics' ) )
        else
          data[:data]['metrics'].push( metricsTomcat.dig('metrics') )
          data[:data]['metrics'].push( tomcatApplication.dig( service, 'metrics' ) )
        end
      end


      if( application != nil )

        if( dataSource == 'redis' )
          data['metrics'].push( metricsTomcat.dig( 'metrics' ) )
        else
          data[:data]['metrics'].push( metricsTomcat.dig( 'metrics' ) )
        end

        application.each do |a|

          if( tomcatApplication.dig( a ) != nil )

            logger.debug( "  add application metrics for #{a}" )

            applicationMetrics = tomcatApplication.dig( a, 'metrics' )

            if( solr_cores != nil )

              if( dataSource == 'redis' )
                data['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
              else
                data[:data]['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
              end
            end

            # remove unneeded Templates
            tomcatApplication[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

#            data[:data]['metrics'].push( metricsTomcat['metrics'] )
            if( dataSource == 'redis' )
              data['metrics'].push( applicationMetrics )
            else

              data[:data]['metrics'].push( applicationMetrics )
            end
          end
        end

      end


      if( dataSource == 'redis' )

        data['metrics'].compact!   # remove 'nil' from array
        data['metrics'].flatten!   # clean up and reduce depth

        return data

      else
        data[:data]['metrics'].compact!   # remove 'nil' from array
        data[:data]['metrics'].flatten!   # clean up and reduce depth

        return data[:data]
      end

    end

  end


  class Collector

    include Logging

    def initialize( settings = {} )

      jolokiaHost         = settings.dig(:jolokia, :host)           || 'localhost'
      jolokiaPort         = settings.dig(:jolokia, :port)           ||  8080
      jolokiaPath         = settings.dig(:jolokia, :path)           || '/jolokia'
      jolokiaAuthUser     = settings.dig(:jolokia, :auth, :user)
      jolokiaAuthPass     = settings.dig(:jolokia, :auth, :pass)
      mqHost              = settings.dig(:mq, :host)                || 'localhost'
      mqPort              = settings.dig(:mq, :port)                || 11300
      @mqQueue            = settings.dig(:mq, :queue)               || 'mq-collector'

      @redisHost          = settings.dig(:redis, :host)
      @redisPort          = settings.dig(:redis, :port)  || 6379

      @applicationConfig  = settings.dig(:configFiles, :application)
      @serviceConfig      = settings.dig(:configFiles, :service)

      version            = '1.8.0'
      date               = '2017-04-12'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - DataCollector' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
      logger.info( "    - redis        : #{@redisHost}:#{@redisPort}" )
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )

      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      @redis              = Storage::RedisClient.new( { :redis => { :host => @redisHost } } )
      @jolokia            = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort, :path => jolokiaPath, :auth => { :user => jolokiaAuthUser, :pass => jolokiaAuthPass } } )
      @mq                 = MessageQueue::Consumer.new( @MQSettings )

      if( @applicationConfig == nil || @serviceConfig == nil )
        msg = 'no Configuration File given'
        logger.error( msg )

        fail msg
      end

        # run internal scheduler to remove old data
        scheduler = Rufus::Scheduler.new

        scheduler.every( 10 ) do
          clean()
        end

    end


    def timeParser( today, finalDate )

      difference = TimeDifference.between( today, finalDate ).in_each_component

      return {
        :years   => difference[:years].round,
        :months  => difference[:months].round,
        :weeks   => difference[:weeks].round,
        :days    => difference[:days].round,
        :hours   => difference[:hours].round,
        :minutes => difference[:minutes].round,
      }
    end


    def mongoDBData( host, data = {} )

      port = 28017

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else


        m = ExternalClients::MongoDb.new( { :host => host, :port => port } )

        return m.get()
      end

  end


    def mysqlData( host, data = {} )

#      data = {}
      user = data.dig('user') || 'cm_management'
      pass = data.dig('pass') || 'cm_management'
      port = data.dig('port') || 3306

      if( port != nil )

        # TODO
        # we need an low-level-priv User for Monitoring!
        settings = {
          :host     => host,
          :username => user,
          :password => pass
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::MySQL.new( { :host => host, :username => user, :password => pass } )

        if( m != nil || m != false )

          mysqlData = m.get()

          if( mysqlData == false || mysqlData == nil )
            mysqlData   = JSON.generate( { :status => 500 } )
          end

          data          = JSON.parse( mysqlData )
        end
      end

      return data

    end


    def postgresData( host, data = {} )

      # WiP and nore sure
      # return

      user = data.dig('user')     || 'cm_management'
      pass = data.dig('pass')     || 'cm_management'
      port = data.dig('port')     || 5432
      dbname = data.dig('dbname') || 'coremedia'

      if( port != nil )

        settings = {
          'postgresHost'   => host,
          'postgresUser'   => user,
          'postgresPass'   => pass,
          'postgresPort'   => port,
          'postgresDBName' => dbname
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        pgsql = ExternalClients::PostgresStatus.new( settings )
        data = pgsql.run()

        logger.debug( data )

      end

    end


    def nodeExporterData( host, data = {} )

      port = data.dig(:port) || 9100

      if( port != nil )

        settings = {
          :host => host,
          :port => port
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::NodeExporter.new( settings )
        nodeData = m.get()

        result   = JSON.generate( nodeData )
        data     = JSON.parse( result )

        return data
      end

    end


    def resourcedData( host, data = {} )

      port = data.dig(:port) || 55555

      if( port != nil )

        settings = {
          :host => host,
          :port => port
        }
      end


      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::Resouced.new( settings )
        nodeData = m.get()

        result   = JSON.generate( nodeData )
        data     = JSON.parse( result )

        return data
      end

    end


    # return all known and active (online) server for monitoring
    #
    def monitoredServer()

      d = @redis.nodes( { :status => 1 } )

      return d

    end

    # create a singulary json for every services to send them to the jolokia service
    #
    def createBulkCheck( params = {} )

      host = params.dig(:hostname)
      fqdn = params.dig(:fqdn)

#       logger.debug( params )

      checks   = Array.new()
      array    = Array.new()
      services = nil

      result = {
        :timestamp   => Time.now().to_i
      }

      logger.debug( sprintf( 'create bulk checks for \'%s\'', host ) )

      # to improve performance, read initial collector Data from Database and store them into Redis
      #
      key       = Storage::RedisClient.cacheKey( { :host => host, :pre => 'collector' } )
      data      = @redis.get( key )

      # recreate the cache every 10 minutes
      #
      if ( data != nil )

        today     = Time.now().to_s
        timestamp = data.dig( 'timestamp' ) || Time.now().to_s

        x = self.timeParser( today, timestamp )
#         logger.debug( x )

        if( x[:minutes] >= 10 )
          data = nil
        end

      end

      if( data == nil )

        data = @redis.measurements( { :short => host } )
#         logger.debug( data )

        if( data == nil || data == false )
          return
        else
          data['timestamp'] = Time.now().to_s

          @redis.set( key, data )
        end

      end

      if( data == nil )
        logger.error( 'no services found. skip ...' )
        return
      end

      data.reject! { |t| t[/timestamp/] }

      services      = data.keys
      servicesCount = services.count

      logger.info( sprintf( '%d services found', servicesCount ) )

      data.each do |s,d|

#         logger.debug( s )
#         logger.debug( d )

        port    = d.dig( 'port' )    || -1
        metrics = d.dig( 'metrics' ) || []
        bulk    = Array.new()

        logger.debug( sprintf( '    %s with port %d', s, port ) )

        if( metrics != nil && metrics.count == 0 )
          case s
          when 'mysql'
            # MySQL
            bulk.push( '' )
          when 'mongodb'
            # MongoDB
            bulk.push( '' )
          when 'node_exporter'
            # Node Exporter (from Prometheus)
            bulk.push( '' )
          when 'postgres'
            # Postgres
            bulk.push( '' )
          when 'resourced'
            # resourced
          else
            # all others
          end
        else

          metrics.each do |e|

            target = {
              'type'   => 'read',
              'mbean'  => e['mbean'].to_s,
              'target' => { 'url' => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", fqdn, port ) },
              'config' => { 'ignoreErrors' => true, 'ifModifiedSince' => true, 'canonicalNaming' => true }
            }

            attributes = []
            if( e['attribute'] )
              e['attribute'].split(',').each do |t|
                attributes.push( t.to_s )
              end

              target['attribute'] = attributes
            end

            bulk.push( target )
          end
        end

        if( bulk.count != 0 )
          checks.push( { s => bulk.flatten } )
        end

      end

      checks.flatten!

      result[:hostname] = host
      result[:fqdn]     = fqdn
      result[:services] = *services
      result[:checks]   = *checks

#       logger.debug( JSON.pretty_generate( result ) )
        # send json to jolokia
      self.collectMeasurements( result )

      checks.clear()
      result.clear()

      return

    end


    # extract Host and Port of destination services from rmi uri
    #  - rmi uri are : "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
    #    host: moebius-16-tomcat
    #    port: 2222
    def checkHostAndService( targetUrl )

      result = false

      regex = /
        ^                   # Starting at the front of the string
        (.*):\/\/           # all after the douple slashes
        (?<host>.+\S)       # our hostname
        :                   # seperator between host and port
        (?<port>\d+)        # our port
      /x

      # prepare
      parts     = targetUrl.match( regex )
      destHost  = parts['host'].to_s.strip
      destPort  = parts['port'].to_s.strip

      logger.debug( sprintf( 'check Port %s on Host %s for sending data', destPort, destHost ) )

      result = Utils::Network.portOpen?( destHost, destPort )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', destPort, destHost ) )
      end

      return result

    end


    # collect measurements data
    #  - send json data to jolokia
    #  - or get data from external services
    # and save the result in an memory storage
    #
    def collectMeasurements( params = {} )

      if( @jolokia.jolokiaIsAvailable?() == false )

        logger.error( 'jolokia service is not available!' )

        return {
          :status  => 500,
          :message => 'jolokia service is not available!'
        }
      end

      hostname  = params.dig(:hostname)
      fqdn      = params.dig(:fqdn)
      checks    = params.dig(:checks)

      result    = {
        :hostname  => hostname,
        :fqdn      => fqdn,
        :timestamp => Time.now().to_i
      }

      checks.each do |c|

        c.each do |v,i|

          logger.debug( sprintf( '%d checks for service \'%s\' found', i.count, v ) )

          cacheKey = Storage::RedisClient.cacheKey( { :host => hostname, :pre => 'result', :service => v } )

          if( i.count > 1 )

            targetUrl = i.first.dig( 'target', 'url' )

            if( self.checkHostAndService( targetUrl ) == true )

              response  = @jolokia.post( { :payload => i, :timeout => 15 } )

              if( response[:status].to_i == 200 )
                result[v] = self.reorganizeData( response[:message] )
              end
            end

          else

            case v
            when 'mysql'
              # MySQL
              result[v] = self.mysqlData( fqdn )
            when 'mongodb'
              # MongoDB
              result[v] = self.mongoDBData( fqdn )
            when 'postgres'
              # Postgres
              result[v] = self.postgresData( fqdn )
            when 'node_exporter'
              # node_exporter
              result[v] = self.nodeExporterData( fqdn )
            when 'resourced'
              #
              result[v] = self.resourcedData( fqdn )
            else
              # all others
            end

#             logger.debug( result[v] )
          end

          if( @redis.set( cacheKey, result[v] ) == false )

            logger.error( sprintf( 'value for key % can not be write', cacheKey ) )
            logger.error( { :host => hostname, :pre => 'result', :service => v } )
          end

        end
      end
    end


    # reorganize data to later simple find
    def reorganizeData( data )

      if( data == nil )
        logger.error( "      no data for reorganize" )
        logger.error( "      skip" )
        return nil
      end

      result  = Array.new()

      data.each do |c|

        mbean      = c.dig('request', 'mbean')
        request    = c.dig('request')
        value      = c.dig('value')
        timestamp  = c.dig('timestamp')
        status     = c.dig('status')

        if( request == nil )

          logger.error( 'wrong data format ... skip reorganizing' )
          next
        end

        # "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
        regex = /
          ^                   # Starting at the front of the string
          (.*):\/\/           # all after the douple slashes
          (?<host>.+\S)       # our hostname
          :                   # seperator between host and port
          (?<port>\d+)        # our port
        /x

        uri   = request.dig('target', 'url')
        parts = uri.match( regex )
        host  = parts['host'].to_s.strip
        port  = parts['port'].to_s.strip


        if( mbean.include?( 'Cache.Classes' ) )

#           logger.debug( mbean )

          regex = /
            CacheClass=
            "(?<type>.+[a-zA-Z])"
            /x
          parts           = mbean.match( regex )
          cacheClass      = parts['type'].to_s

          if( cacheClass.include?( 'ecommerce.' ) )
            format   = 'CacheClassesECommerce%s'
          else
            format   = 'CacheClasses%s'
          end

          cacheClass     = cacheClass.split('.').last
          cacheClass[0]  = cacheClass[0].to_s.capitalize
          mbean_type     = sprintf( format, cacheClass )


        elsif( mbean.include?( 'module=' ) )
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            module=               #
            (?<module>.+[a-zA-Z]) #
            (.*)                  #
            pool=                 #
            (?<pool>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
          /x

          parts           = mbean.match( regex )
          mbeanModule     = parts['module'].to_s.strip.tr( '. ', '' )
          mbeanPool       = parts['pool'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanPool )

        elsif( mbean.include?( 'bean=' ) )

          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            bean=                 #
            (?<bean>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanBean       = parts['bean'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanBean )

        elsif( mbean.include?( 'name=' ) )
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            name=                 #
            (?<name>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanName       = parts['name'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanName )

        elsif( mbean.include?( 'solr') )

          regex = /
            ^                     # Starting at the front of the string
            solr\/                #
            (?<core>.+[a-zA-Z0-9]):  #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanCore       = parts['core'].to_s.strip.tr( '. ', '' )
          mbeanCore[0]    = mbeanCore[0].to_s.capitalize
          mbeanType       = parts['type'].to_s.tr( '. /', '' )
          mbeanType[0]    = mbeanType[0].to_s.capitalize
          mbean_type      = sprintf( 'Solr%s%s', mbeanCore, mbeanType )

        else
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s', mbeanType )
        end

        result.push(
          mbean_type.to_s => {
            'status'    => status,
            'timestamp' => timestamp,
            'host'      => host,
            'port'      => port,
            'request'   => request,  # OBSOLETE, can be removed
            'value'     => value
          }
        )

      end

      return result
    end


    def clean()

      data = @mq.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        logger.debug( data )

        payload = data.dig( :body, 'payload' )

        logger.debug( payload )

        cacheKey = Storage::RedisClient.cacheKey( { :host => payload.dig('host'), :pre => 'prepare' } )

        @redis.set( cacheKey, '' )
      end
    end


    def prepareData( params = {} )

      shortName  = params.dig(:hostname)
      fqdn      = params.dig(:fqdn)

      # TODO
      #
      prepared = @redis.get( Storage::RedisClient.cacheKey( { :host => shortName, :pre => 'prepare' } ) )

#       logger.debug( prepared )
#       logger.debug( prepared.class.to_s )

      if( prepared.is_a?( NilClass ) || prepared.is_a?( FalseClass ) || ( prepared.is_a?( String ) && ( prepared == '' || prepared == 'false ' ) ) )

        result = false

        logger.debug( 'no prepared data found ...' )

        start = Time.now

        # no prepared data found ...
        # generate it
        options = {
          :configFiles           => { :application => @applicationConfig, :service => @serviceConfig },
          :applicationConfigFile => @applicationConfig,
          :serviceConfigFile     => @serviceConfig,
          :redis                 => { :host => @redisHost, :port => @redisPort }
        }

        p = Prepare.new( options )
        result = p.buildMergedData( { :hostname => shortName, :fqdn => fqdn } )

        if( result == true )
          @redis.set( Storage::RedisClient.cacheKey( { :host => shortName, :pre => 'prepare' } ), { :prepared => true } )
        end

        finish = Time.now
        logger.info( sprintf( 'build prepared data in %s seconds', finish - start ) )

      end

    end


    def run()

      logger.debug( 'get monitored Servers' )

      monitoredServer = self.monitoredServer()

      if( monitoredServer.is_a?( FalseClass ) || monitoredServer.count == 0 )

        logger.info( 'no Servers for Monitoring found' )

        return
      end

      monitoredServer.each do |h,d|

        h = h.first

        shortName = d.dig(:shortname)
        fqdn      = d.dig(:longname)

        start = Time.now

        logger.info( sprintf( 'found %s for monitoring', fqdn ) )

        # build prepared datas
        self.prepareData( { :hostname => shortName, :fqdn => fqdn } )

        # run checks
        self.createBulkCheck( { :hostname => shortName, :fqdn => fqdn } )

        finish = Time.now
        logger.info( sprintf( 'collect data in %s seconds', finish - start ) )
      end

    end

  end

end

