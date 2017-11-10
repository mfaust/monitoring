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
require 'mini_cache'
require 'rufus-scheduler'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'monkey'
require_relative 'jolokia'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'external-clients'

require_relative 'collector/version'
require_relative 'collector/tools'
require_relative 'collector/config'
require_relative 'collector/prepare'

# -----------------------------------------------------------------------------

module DataCollector

  class Collector

    include Logging

#     include DataCollector::Version
    include DataCollector::Tools

    def initialize( settings = {} )

      jolokia_host        = settings.dig(:jolokia, :host)           || 'localhost'
      jolokia_port        = settings.dig(:jolokia, :port)           ||  8080
      jolokia_path        = settings.dig(:jolokia, :path)           || '/jolokia'
      jolokia_auth_user   = settings.dig(:jolokia, :auth, :user)
      jolokia_auth_pass   = settings.dig(:jolokia, :auth, :pass)
      mq_host             = settings.dig(:mq, :host)                || 'localhost'
      mq_port             = settings.dig(:mq, :port)                || 11300
      @mq_queue           = settings.dig(:mq, :queue)               || 'mq-collector'

      redis_host          = settings.dig(:redis, :host)
      redis_port          = settings.dig(:redis, :port)  || 6379

      application_config  = settings.dig(:configFiles, :application)
      service_config      = settings.dig(:configFiles, :service)

      mysql_host          = settings.dig(:mysql, :host)
      mysql_schema        = settings.dig(:mysql, :schema)
      mysql_user          = settings.dig(:mysql, :user)
      mysql_password      = settings.dig(:mysql, :password)

      version             = DataCollector::VERSION
      date                = DataCollector::DATE

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - DataCollector' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokia_host}:#{jolokia_port}" )
      logger.info( "    - redis        : #{redis_host}:#{redis_port}" )
      logger.info( "    - mysql        : #{mysql_host}@#{mysql_schema}" )
      logger.info( "    - message queue: #{mq_host}:#{mq_port}/#{@mq_queue}" )
      logger.info( '-----------------------------------------------------------------' )

      if( application_config.nil? || service_config.nil? )
        msg = 'no Configuration File given'
        logger.error( msg )
        fail msg
      end

      mq_settings = {
        :beanstalkHost => mq_host,
        :beanstalkPort => mq_port
      }

      prepareSettings = {
        :configFiles => { :application => application_config, :service => service_config },
        :redis       => { :host => redis_host, :port => redis_port }
      }

      mysql_settings = { mysql: { host: mysql_host, user: mysql_user, password: mysql_password, schema: mysql_schema } }

      @cache     = MiniCache::Store.new()
      @redis     = Storage::RedisClient.new( { :redis => { :host => redis_host } } )
      @jolokia   = Jolokia::Client.new( { :host => jolokia_host, :port => jolokia_port, :path => jolokia_path, :auth => { :user => jolokia_auth_user, :pass => jolokia_auth_pass } } )
      @mq        = MessageQueue::Consumer.new(mq_settings )
      @cfg       = Config.new( application: application_config, service: service_config )
      @prepare   = Prepare.new( redis: @redis, config: @cfg ) # prepareSettings )
      @jobs      = JobQueue::Job.new()
      @database  = Storage::MySQL.new( mysql_settings )

      # run internal scheduler to remove old data
      scheduler = Rufus::Scheduler.new

      scheduler.every( 10, :first_in => 10 ) do
        clean()
      end

    end


    def mongodb_data( host, data = {} )

      port = 28017

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.warn( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::MongoDb.new( { :host => host, :port => port } )

        return m.get()
      end
    end


    def mysql_data( host, data = {} )

      user = data.dig('user') || 'monitoring'
      pass = data.dig('pass') || 'monitoring'
      port = data.dig('port') || 3306
      cache_key = format('mysql-%s', host)

      cached_data = @cache.get( cache_key )

      unless( cached_data.nil? )
        user = cached_data.dig(:user)
        pass = cached_data.dig(:pass)
        port = cached_data.dig(:port)
      end

      unless( port.nil? )
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
        logger.warn( sprintf( 'The Port \'%s\' on Host \'%s\' is not open, skip ...', port, host ) )

        return JSON.parse( JSON.generate( status: 500 ) )
      else

        m = ExternalClients::MySQL.new( settings )

        if( m.client.nil? )

          fallback = {
            coremedia: 'coremedia',
            cm_replication: 'cm_replication',
            cm_caefeeder: 'cm_caefeeder',
            cm_mcaefeeder: 'cm_mcaefeeder',
            cm_management: 'cm_management',
            cm_master: 'cm_master'
          }

          fallback.each do |u,p|

            settings = { host: host, username: u, password: p }

            m = ExternalClients::MySQL.new( settings )

            unless( m.client.nil? )

              user = u.clone
              pass = p.clone
              break
            end
          end

        end

        unless( m.client.nil? )

          @cache.set( cache_key , expires_in: 640 ) { MiniCache::Data.new( user: user, pass: pass, port: port ) }

          mysql_data = m.get()
          mysql_data = JSON.generate( status: 500 ) if( mysql_data == false || mysql_data.nil? )

          data       = JSON.parse( mysql_data )
        end
      end

      data
    end


    def postgres_data( host, data = {} )

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
        logger.warn( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        pgsql = ExternalClients::PostgresStatus.new( settings )
        data = pgsql.run()

#         logger.debug( data )
      end

    end


    def redis_data( host, data = {} )

      logger.debug("redis_data( #{host}, #{data} )")

      port = data.dig(:port) || 6379

      unless( port.nil? )

        settings = {
          :host => host,
          :port => port
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.warn( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        logger.debug( 'read redis data ...' )

        @redis.monitoring
      end
    end


    def node_exporter_data( host, data = {} )

      logger.debug("node_exporter_data( #{host}, #{data} )")

      port = data.dig(:port) || 9100

      unless( port.nil? )

        settings = {
          :host => host,
          :port => port
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.warn( sprintf( 'The Port %s on Host %s is not open, skip sending data', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::NodeExporter.new( settings )
        nodeData = m.get()

        result   = JSON.generate( nodeData )
        data     = JSON.parse( result )

        return data
      end

    end


    def resourced_data( host, data = {} )

      port = data.dig(:port) || 55555

      if( port != nil )
        settings = {
          :host => host,
          :port => port
        }
      end

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.warn( sprintf( 'The Port \'%s\' on Host \'%s\' is not open, skip ...', port, host ) )

        return JSON.parse( JSON.generate( { :status => 500 } ) )
      else

        m = ExternalClients::Resouced.new( settings )
        nodeData = m.get()

        result   = JSON.generate( nodeData )
        data     = JSON.parse( result )

        return data
      end

    end


    def apache_mod_status( host, data = {} )

      logger.debug( "apache_mod_status( #{host}, #{data} )" )

      port = data.dig(:port) || 8081

      result = Utils::Network.portOpen?( host, port )

      if( result == false )
        logger.warn( sprintf( 'The Port \'%s\' on Host \'%s\' is not open, skip ...', port, host ) )

        JSON.parse( JSON.generate( status: 500 ) )
      else

#        result = []

        mod_status      = ExternalClients::ApacheModStatus.new( host: host, port: port )
        mod_status_data = mod_status.tick

        return { status: mod_status_data }
      end
    end


    # return all known and active (online) server for monitoring
    #
    def monitoredServer()

      @database.nodes( status: [ Storage::MySQL::ONLINE ] )
    end

    # create a singulary json for every services to send them to the jolokia service
    #
    def create_bulkcheck( params )

      logger.debug( "create_bulkcheck( #{params} )" )

      ip   = params.dig(:ip)
      host = params.dig(:short)
      fqdn = params.dig(:fqdn)

      if( host.nil? )
        logger.warn( 'no host name for bulk checks' )
        return
      end

      checks   = Array.new()
      array    = Array.new()
      services = nil

      result = {
        timestamp: Time.now().to_i
      }

#       logger.debug( sprintf( 'create bulk checks for \'%s\'', host ) )

      # to improve performance, read initial collector Data from Database and store them into Redis
      #
      key       = Storage::RedisClient.cacheKey( host: fqdn, pre: 'collector' )
      data      = @cache.get( key )

      if( data.nil? )

        data = @redis.measurements( short: host, fqdn: fqdn )

        if( data.nil? || data == false )
          @cache.unset( host )
          return
        else
          @cache.set( key ) { MiniCache::Data.new( data ) }
        end

      end

      if( data.nil? )
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
          when 'node-exporter'
            # Node Exporter (from Prometheus)
            bulk.push( '' )
          when 'postgres'
            # Postgres
            bulk.push( '' )
          when 'redis'
            # redis
            bulk.push('')
          when 'resourced'
            # resourced
          when 'http-status'
            bulk.push('')
          else
            # all others
          end
        else

          metrics.each do |e|

            mbean     = e.dig('mbean')
            attribute = e.dig('attribute')

            if( mbean.nil? )
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
            attributes = attribute.split(',') unless( attribute.nil? )

            bulk.push( target )
          end
        end

        checks.push( { s => bulk.flatten } ) if( bulk.count != 0 )
      end

      checks.flatten!

      result[:ip]       = ip
      result[:hostname] = host
      result[:fqdn]     = fqdn
      result[:services] = *services
      result[:checks]   = *checks

#      logger.debug( JSON.pretty_generate( result ) )
        # send json to jolokia
      begin
        self.collect_measurements( result )
      rescue => e
        logger.error(format('collect measurements failed, cause: %s', e ))
      end

      checks.clear()
      result.clear()

      return
    end


    # extract Host and Port of destination services from rmi uri
    #  - rmi uri are : "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
    #    host: moebius-16-tomcat
    #    port: 2222
    def check_host_and_service( targetUrl )

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
        logger.warn( sprintf( 'The Port %s on Host %s is not open, skip sending data', destPort, destHost ) )
      end

      return result

    end


    # collect measurements data
    #  - send json data to jolokia
    #  - or get data from external services
    # and save the result in an memory storage
    #
    def collect_measurements( params )

#       logger.debug( "collect_measurements( #{params} )" )

      if( @jolokia.available? == false )
        logger.error( 'jolokia service is not available!' )
        return { status: 500, message: 'jolokia service is not available!' }
      end

      ip        = params.dig(:ip)
      hostname  = params.dig(:hostname)
      fqdn      = params.dig(:fqdn)
      checks    = params.dig(:checks)

      result    = {
        hostname:  hostname,
        fqdn: fqdn,
        timestamp: Time.now().to_i
      }

#       logger.debug( result )
#       logger.debug( checks )
#       logger.debug( checks.count )
#
#       logger.debug('------------------------------------------')

      checks.each do |c|

        c.each do |v,i|

          logger.info( sprintf( 'service \'%s\' has %s checks', v, i.count ) )

          result[v] ||= []

          cacheKey = Storage::RedisClient.cacheKey( host: fqdn, pre: 'result', service: v )

          if( i.count > 1 )

            targetUrl = i.first.dig( 'target', 'url' )

            if( self.check_host_and_service( targetUrl ) == true )

              response       = @jolokia.post( payload: i, timeout: 15, sleep_retries: 3 )

              jolokia_status  = response.dig(:status)
              jolokia_message = response.dig(:message)

#               logger.debug( "jolokia_status : #{jolokia_status}" )
#               logger.debug( "jolokia_message: #{jolokia_message}" )

              if( jolokia_status != nil && jolokia_status.to_i == 200 )

                begin

                  data = self.reorganize_data( jolokia_message )

                  # get configured Content Server (RLS or MLS)
                  if( v =~ /^cae-(\blive|preview).*/ )
                    data = self.parse_content_server_url( fqdn: fqdn, service: v, data: data )
                  end

                  # get configured Master Live Server
                  if( v == 'replication-live-server' )
                    data = self.parse_mls_ior( fqdn: fqdn, data: data )
                  end

                  result[v] = data
                rescue => e
                  logger.error( "i can't store data into result for service #{v}" )
                  logger.error( e )
                  logger.debug( e.backtrace.join("\n") )
                end
              else
                logger.error( "jolokia status : #{jolokia_status}" )
                logger.error( "jolokia message: #{jolokia_message}" )
              end
            end

          else

            d = ''
            case v
            when 'mysql'
              # MySQL
              d = self.mysql_data( fqdn )
            when 'mongodb'
              # MongoDB
              d = self.mongodb_data( fqdn )
            when 'postgres'
              # Postgres
              d = self.postgres_data( fqdn )
            when 'redis'
              # redis
              d = self.redis_data( fqdn )
            when 'node-exporter'
              # node_exporter
              d = self.node_exporter_data( fqdn )
            when 'resourced'
              #
              d = self.resourced_data( fqdn )
            when 'http-status'
              # apache mod_status

              # TODO
              # need better coding
              port = 8081
              begin
                service_config = @cfg.service_config.clone
                port = service_config.dig( 'http-status', 'port' ) || 8081
                logger.debug( port )
              rescue => e
                logger.error(e)
                logger.error( e.backtrace.join("\n") )
              end

              d = self.apache_mod_status( fqdn, { port: port } )
            else
              # all others
            end

            begin
              result[v] = d
            rescue => e
              logger.error( "i can't create data for service #{v}" )
              logger.error( e )
              logger.error( e.backtrace.join("\n") )
            end

          end

          begin

#             logger.debug( 'store result in our redis' )
#             logger.debug( host: fqdn, pre: 'result', service: v ) )

            redis_result = @redis.set( cacheKey, result[v] )

            if( redis_result.is_a?( FalseClass ) || ( redis_result.is_a?( String ) && redis_result != 'OK' ) )
              logger.error( sprintf( 'value for key %s can not be write', cacheKey ) )
              logger.error( host: fqdn, pre: 'result', service: v )
            end

          rescue => e

            logger.error( sprintf( 'value for key \'%s\' can not be write', cacheKey ) )
            logger.error( host: fqdn, pre: 'result', service: v )
            # logger.error( result[v] )
            logger.error( e )
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
    def parse_mls_ior( params = {} )

      mlsIOR = nil

      fqdn    = params.dig(:fqdn)
      data    = params.dig(:data)
      mlsHost = fqdn

      logger.info( '  search Master Live Server for this Replication Live Server' )

      d = data.select { |d| d.dig('Replicator') }

      return data unless( d.is_a?(Array) )

#       unless( d.is_a?(Array) )
#         data
#       end

      value = d.first # hash
      replicator = value.dig('Replicator')

#       logger.debug( value.class.to_s )
#       logger.debug(value)

      status = replicator.dig('status')
#       logger.debug(status)

      if( status.to_i != 200 )
        logger.error( 'Contentserver are not available!' )
        return data
      end

      value = replicator.dig('value')

      return data unless( value.is_a?(Hash) )

#       logger.debug( value.class.to_s )

#       if( !value.is_a?(Hash) )
#         data
#       end
#
#       logger.debug( value )

      unless( value.nil? )

#         logger.debug( value.class.to_s )

        value  = value.values.first

        return data unless( value.is_a?(Hash) )
#
#         logger.debug( value.class.to_s )
#
#         if( !value.is_a?(Hash))
#           data
#         end

        mlsIOR = value.dig( 'MasterLiveServerIORUrl' )

#         logger.debug( mlsIOR )

        unless( mlsIOR.nil? )

          uri    = URI.parse( mlsIOR )
          scheme = uri.scheme
          host   = uri.host
          port   = uri.port
          path   = uri.path

          logger.debug( format('search dns entry for \'%s\'', host) )

          ip, short, fqdn = self.ns_lookup(host, 60)

          if( !ip.nil? && !short.nil? && !fqdn.nil? )

            logger.debug( "found: #{ip} , #{short} , #{fqdn}" )

            realIP    = ip
            realShort = short
            mlsHost   = fqdn

          else
            realIP    = ''
            realShort = ''
            mlsHost   = host
          end

          value['MasterLiveServer'] = {
            'scheme' => scheme,
            'host'   => mlsHost,
            'port'   => port,
            'path'   => path
          }

          logger.debug( JSON.pretty_generate(value.dig('MasterLiveServer')) )

        else
          logger.debug( 'no \'IOR URL\' found! :(' )
          logger.info( 'this RLS use an older version. we use the RLS Host as fallback' )
        end

      end

      logger.info( sprintf( '  use \'%s\'', mlsHost ) )

      return data

    end

    # a CAE give us his Content Server as URL:
    #  - "Url": "http://tomcat-centos7:42080/coremedia/ior"
    #  - "Url": "http://tomcat-centos7:40180/coremedia/ior"

    def parse_content_server_url( params )

      content_server_ior = nil

      fqdn    = params.dig(:fqdn)
      service = params.dig(:service)
      data    = params.dig(:data)
      content_server = fqdn

      logger.info( format( '  search Content Server for this CAE (%s)', service ) )

      d = data.select {|d| d.dig('CapConnection') }

      return data unless( d.is_a?(Array) )

      value = d.first # hash
      cap_connection = value.dig('CapConnection')

#       logger.debug( value.class.to_s )
#       logger.debug(value)

      status = cap_connection.dig('status')
#       logger.debug(status)

      if( status.to_i != 200 )
        logger.error( 'Contentserver are not available!' )
        return data
      end

      value = cap_connection.dig('value')

      return data unless( value.is_a?(Hash) )

#       logger.debug( value ) #

      unless( value.nil? )

        value  = value.values.first

        return data unless( value.is_a?(Hash) )

        content_server_ior = value.dig( 'Url' )

        unless( content_server_ior.nil? )

          uri    = URI.parse( content_server_ior )
          scheme = uri.scheme
          host   = uri.host
          port   = uri.port
          path   = uri.path

          logger.debug( format('search dns entry for \'%s\'', host) )

          ip, short, fqdn = self.ns_lookup(host, 60)

          if( !ip.nil? && !short.nil? && !fqdn.nil? )

            logger.debug( "found: #{ip} , #{short} , #{fqdn}" )

            realIP    = ip
            realShort = short
            content_server = fqdn

          else
            realIP    = ''
            realShort = ''
            content_server = host
          end

          value['ContentServer'] = {
            'scheme' => scheme,
            'host'   => content_server,
            'port'   => port,
            'path'   => path
          }

          logger.debug( JSON.pretty_generate(value.dig('ContentServer')) )
        else
          logger.debug( 'no \'IOR URL\' found! :(' )
          logger.info( 'this CAE use an older version. we use the CAE Host as fallback' )
        end
      end

      logger.info( sprintf( '  use \'%s\'', content_server ) )
      return data
    end


    # reorganize data to later simple find
    #
    def reorganize_data( data )

      if( data.nil? )
        logger.error( "      no data for reorganize" )
        logger.error( "      skip" )
        { status: 500, message: 'no data for reorganize' }
      end

      result  = Array.new()

      data.each do |c|

        request    = c.dig('request')

        if( request.nil? )
          logger.error( 'wrong data format ... skip reorganizing' )
          next
        end

        mbean      = request.dig('mbean')
        value      = c.dig('value')
        timestamp  = c.dig('timestamp')
        status     = c.dig('status')


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

      { status: 204, message: 'no data' } if( result.count == 0 )

      result
    end


    def clean()

      data = @mq.getJobFromTube(@mq_queue, true )

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

      if( monitoredServer.nil? || monitoredServer.is_a?( FalseClass ) || monitoredServer.count == 0 )

        logger.info( 'no online server found' )

        return
      end

      monitoredServer.each do |h|

        # get dns data!
        #
        ip, short, fqdn = self.ns_lookup( h )

        discovery_data = nil

        # add hostname to an blocking cache
        #
        if( @jobs.jobs( short: short, fqdn: fqdn ) == true )

          logger.warn( 'we are working on this job' )
          logger.debug( short: short, fqdn: fqdn )

          next
        end

        logger.debug( 'block this job:' )
        logger.debug( short: short, fqdn: fqdn )
        @jobs.add( short: short, fqdn: fqdn )

        start = Time.now

        logger.info( sprintf( 'found \'%s\' for monitoring', fqdn ) )

        # TODO
        # discussion
        # we need this in realtime, or can we cache this for ... 1 minute or more?
        #
        begin
          discovery_data    = @database.discoveryData( ip: ip, short: short, fqdn: fqdn )
        rescue => e
          logger.error(e)
        end

        # build prepared datas
        #
        begin
          @prepare.buildMergedData( hostname: short, fqdn: fqdn, data: discovery_data )
        rescue => e
          logger.error(e)
        end

        # run checks
        #
        begin
          self.create_bulkcheck( ip: ip, short: short, fqdn: fqdn )
        rescue => e
          logger.error(e)
        end

        finish = Time.now
        logger.info( sprintf( 'collect data in %s seconds', (finish - start).round(2) ) )

        logger.debug( 'give job free:' )
        logger.debug( short: short, fqdn: fqdn )
        @jobs.del( short: short, fqdn: fqdn )

      end

    end

  end

end

