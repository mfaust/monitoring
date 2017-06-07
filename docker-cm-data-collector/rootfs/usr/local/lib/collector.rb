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
require_relative 'cache'
require_relative 'utils/network'
require_relative 'monkey'
require_relative 'jolokia'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'external-clients'

require_relative 'collector/tools'
require_relative 'collector/config'
require_relative 'collector/prepare'

# -----------------------------------------------------------------------------

module DataCollector

  class Collector

    include Logging

    include DataCollector::Tools

    def initialize( settings = {} )

      jolokiaHost         = settings.dig(:jolokia, :host)           || 'localhost'
      jolokiaPort         = settings.dig(:jolokia, :port)           ||  8080
      jolokiaPath         = settings.dig(:jolokia, :path)           || '/jolokia'
      jolokiaAuthUser     = settings.dig(:jolokia, :auth, :user)
      jolokiaAuthPass     = settings.dig(:jolokia, :auth, :pass)
      mqHost              = settings.dig(:mq, :host)                || 'localhost'
      mqPort              = settings.dig(:mq, :port)                || 11300
      @mqQueue            = settings.dig(:mq, :queue)               || 'mq-collector'

      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)  || 6379

      applicationConfig   = settings.dig(:configFiles, :application)
      serviceConfig       = settings.dig(:configFiles, :service)

      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      version            = '1.9.2'
      date               = '2017-06-07'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - DataCollector' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
      logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
      logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )

      if( applicationConfig == nil || serviceConfig == nil )
        msg = 'no Configuration File given'
        logger.error( msg )

        fail msg
      end

      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      prepareSettings = {
        :configFiles => { :application => applicationConfig, :service => serviceConfig },
        :redis       => { :host => redisHost, :port => redisPort }
      }

      @cache     = Cache::Store.new()
      @redis     = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
      @jolokia   = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort, :path => jolokiaPath, :auth => { :user => jolokiaAuthUser, :pass => jolokiaAuthPass } } )
      @mq        = MessageQueue::Consumer.new( @MQSettings )
      @prepare   = Prepare.new( prepareSettings )
      @jobs      = JobQueue::Job.new()
      @database   = nil

      if( mysqlHost != nil )

        begin

          until( @database != nil )

            @database   = Storage::MySQL.new( {
              :mysql => {
                :host     => mysqlHost,
                :user     => mysqlUser,
                :password => mysqlPassword,
                :schema   => mysqlSchema
              }
            } )

          end
        rescue => e

          logger.error( e )
        end
      end

      # run internal scheduler to remove old data
      scheduler = Rufus::Scheduler.new

      scheduler.every( 10, :first_in => 10 ) do
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

#         logger.debug( data )

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

      nodes = @database.nodes( { :status => [ Storage::MySQL::ONLINE ] } )

      return nodes
    end

    # create a singulary json for every services to send them to the jolokia service
    #
    def createBulkCheck( params = {} )

      host = params.dig(:hostname)
      fqdn = params.dig(:fqdn)

#       logger.debug( "createBulkCheck( #{params} )" )

      if( host == nil )
        logger.warn( 'no host name for bulk checks' )
        return
      end

      checks   = Array.new()
      array    = Array.new()
      services = nil

      result = {
        :timestamp   => Time.now().to_i
      }

#       logger.debug( sprintf( 'create bulk checks for \'%s\'', host ) )

      # to improve performance, read initial collector Data from Database and store them into Redis
      #
      key       = Storage::RedisClient.cacheKey( { :host => fqdn, :pre => 'collector' } )
      data      = @cache.get( key )

      if( data == nil )

        data = @redis.measurements( { :short => host } )

        if( data == nil || data == false )
          @cache.unset( host )
          return
        else
          @cache.set( key ) { Cache::Data.new( data ) }
        end

      end

      if( data == nil )
        logger.error( 'no services found. skip ...' )
        return
      end

      services      = data.keys
      servicesCount = services.count

      logger.info( sprintf( '%d services found', servicesCount ) )

      data.each do |s,d|

        port    = d.dig( 'port' )    || -1
        metrics = d.dig( 'metrics' ) || []
        bulk    = Array.new()

        # only to see which service
        #
#         logger.debug( sprintf( '    %s with port %d', s, port ) )

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

            mbean     = e.dig('mbean')
            attribute = e.dig('attribute')

            if( mbean == nil )
              logger.error( '\'mbean\' are nil!' )
              next
            end

            target = {
              'type'   => 'read',
              'mbean'  => mbean.to_s,
              'target' => { 'url' => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", fqdn, port ) },
              'config' => { 'ignoreErrors' => true, 'ifModifiedSince' => true, 'canonicalNaming' => true }
            }

            attributes = []

            if( attribute != nil )

              attributes = attribute.split(',')
            end

#             if( e['attribute'] )
#               e['attribute'].split(',').each do |t|
#                 attributes.push( t.to_s )
#               end
#
#               target['attribute'] = attributes
#             end

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

#       logger.debug( sprintf( 'check Port %s on Host %s for sending data', destPort, destHost ) )

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

#       logger.debug( "collectMeasurements( #{params} )" )

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

          logger.info( sprintf( 'service \'%s\' has %d checks', v, i.count ) )

          result[v] ||= []

          cacheKey = Storage::RedisClient.cacheKey( { :host => fqdn, :pre => 'result', :service => v } )

          if( i.count > 1 )

            targetUrl = i.first.dig( 'target', 'url' )

            if( self.checkHostAndService( targetUrl ) == true )

              response       = @jolokia.post( { :payload => i, :timeout => 15 } )

              jolokiaStatus  = response.dig(:status)
              jolokiaMessage = response.dig(:message)

              if( jolokiaStatus != nil && jolokiaStatus.to_i == 200 )

                begin

                  data = self.reorganizeData( jolokiaMessage )

                  if( v == 'replication-live-server' )
                    data = self.parseMLSIor( { :fqdn => fqdn, :data => data } )
                  end

                  result[v] = data
                rescue => e
                  logger.error( "i can't store data into result for service #{v}" )
                  logger.error( e )
                end
              else
                logger.error( "jolokia status : #{jolokiaStatus}" )
                logger.error( "jolokia message: #{jolokiaMessage}" )
              end
            end

          else

            d = ''
            case v
            when 'mysql'
              # MySQL
              d = self.mysqlData( fqdn )
            when 'mongodb'
              # MongoDB
              d = self.mongoDBData( fqdn )
            when 'postgres'
              # Postgres
              d = self.postgresData( fqdn )
            when 'node_exporter'
              # node_exporter
              d = self.nodeExporterData( fqdn )
            when 'resourced'
              #
              d = self.resourcedData( fqdn )
            else
              # all others
            end

            begin
              result[v] = d
            rescue => e
              logger.error( "i can't store data into result for service #{v}" )
              logger.error( e )
            end

          end

#           logger.debug( 'store result in our redis' )
          redisResult = @redis.set( cacheKey, result[v] )

          if( redisResult.is_a?( FalseClass ) || ( redisResult.is_a?( String ) && redisResult != 'OK' ) )

            logger.error( sprintf( 'value for key % can not be write', cacheKey ) )
            logger.error( { :host => fqdn, :pre => 'result', :service => v } )
          end

        end
      end
    end


    # the RLS give us his MLS as URL: "MasterLiveServerIORUrl": "http://tomcat-centos7:40280/coremedia/ior"
    # we extract the value with the real hostname for later usage:
    # "MasterLiveServer": {
    #   "scheme": "http",
    #   "host": "tomcat-centos7",
    #   "port": 40280,
    #   "path": "/coremedia/ior"
    # }
    #
    def parseMLSIor( params = {} )

      mlsIOR = nil

      fqdn   = params.dig(:fqdn)
      data   = params.dig(:data)

      logger.info( 'search Master Live Server IOR for the Replication Live Server' )

      d = data.select {|d| d.dig('Replicator') }

      value = d.first.dig( 'Replicator','value' )

      if( value != nil )

        value  = value.values.first
        mlsIOR = value.dig( 'MasterLiveServerIORUrl' )

        if( mlsIOR != nil )

          uri    = URI.parse( mlsIOR )
          scheme = uri.scheme
          host   = uri.host
          port   = uri.port
          path   = uri.path

          ip, short, fqdn = self.nsLookup( host )

          dns = @database.dnsData( { :ip => ip, :short => short, :fqdn => fqdn } )

          realIP    = dns.dig('ip')   || ip
          realShort = dns.dig('name') || short
          realFqdn  = dns.dig('fqdn') || fqdn

          value['MasterLiveServer'] = {
            'scheme' => scheme,
            'host'   => realShort,
            'port'   => port,
            'path'   => path
          }
        end

      end
#       logger.debug( JSON.pretty_generate( data ) )
      return data

    end


    # reorganize data to later simple find
    #
    def reorganizeData( data )

      if( data == nil )
        logger.error( "      no data for reorganize" )
        logger.error( "      skip" )

        return {
          :status  => 500,
          :message => 'no data for reorganize'
        }
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

      data = @mq.getJobFromTube( @mqQueue, true )

      if( data.count() != 0 )

        logger.debug( data )

        payload = data.dig( :body, 'payload' )

        logger.debug( payload )

        @cache.unset( payload.dig('host') )
      end
    end



    def run()

#      logger.debug( 'get the online server for monitoring to collect their data' )

      monitoredServer = self.monitoredServer()

#       logger.debug( monitoredServer )

      if( monitoredServer == nil || monitoredServer.is_a?( FalseClass ) || monitoredServer.count == 0 )

        logger.info( 'no online server found' )

        return
      end

      monitoredServer.each do |h|

        # get dns data!
        #
        ip, short, fqdn = self.nsLookup( h )

        discoveryData = nil

        # add hostname to an blocking cache
        #
        if( @jobs.jobs( { :short => short, :fqdn => fqdn } ) == true )

          logger.warn( 'we are working on this job' )

          next
        end

        @jobs.add( { :short => short, :fqdn => fqdn } )

        start = Time.now

        logger.info( sprintf( 'found \'%s\' for monitoring', fqdn ) )

        if( @database != nil )

          # TODO
          # discussion
          # we need this in realtime, or can we cache this for ... 1 minute or more?
          #
          discoveryData    = @database.discoveryData( { :ip => ip, :short => short, :fqdn => fqdn } )
        end

        # build prepared datas
        #
        @prepare.buildMergedData( { :hostname => short, :fqdn => fqdn, :data => discoveryData } )

        # run checks
        #
        self.createBulkCheck( { :hostname => short, :fqdn => fqdn } )

        finish = Time.now
        logger.info( sprintf( 'collect data in %s seconds', finish - start ) )

        @jobs.del( { :short => short, :fqdn => fqdn } )

      end

    end

  end

end

