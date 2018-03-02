#!/usr/bin/ruby
#
# 14.09.2016 - Bodo Schulz
#
#
# v1.4.2

# -----------------------------------------------------------------------------

require 'time'
require 'date'
require 'json'
require 'filesize'
require 'fileutils'
require 'mini_cache'
require 'storage'

require_relative 'logging'

require_relative 'mbean'

require_relative 'carbon-data/version'
require_relative 'carbon-data/utils'
require_relative 'carbon-data/tomcat'
require_relative 'carbon-data/cae'
require_relative 'carbon-data/content-server'
require_relative 'carbon-data/clients'
require_relative 'carbon-data/feeder'
require_relative 'carbon-data/solr'
require_relative 'carbon-data/http'
require_relative 'carbon-data/database/mongodb'
require_relative 'carbon-data/database/mysql'
require_relative 'carbon-data/database/postgres'
require_relative 'carbon-data/operating-system/node-exporter'

# -----------------------------------------------------------------------------

module CarbonData

  class Consumer

    include Logging

    include CarbonData::Utils
    include CarbonData::Tomcat
    include CarbonData::Cae
    include CarbonData::ContentServer
    include CarbonData::Clients
    include CarbonData::Feeder
    include CarbonData::Solr
    include CarbonData::Http::Apache
    include CarbonData::Database::MongoDB
    include CarbonData::Database::MySQL
    include CarbonData::Database::Postgres
    include CarbonData::OperatingSystem::NodeExporter

    def initialize( settings = {} )

      redis_host      = settings.dig(:redis, :host)
      redis_port      = settings.dig(:redis, :port)             || 6379

      mysql_host      = settings.dig(:mysql, :host)
      mysql_schema    = settings.dig(:mysql, :schema)
      mysql_user      = settings.dig(:mysql, :user)
      mysql_password  = settings.dig(:mysql, :password)

      version         = CarbonData::VERSION
      date            = CarbonData::DATE

      redis_settings  = { redis: { host: redis_host } }
      mysql_settings  = { mysql: { host: mysql_host, user: mysql_user, password: mysql_password, schema: mysql_schema } }

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - CarbonData' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - redis        : #{redis_host}:#{redis_port}" )
      if( mysql_host != nil )
        logger.info( "    - mysql        : #{mysql_host}@#{mysql_schema}" )
      end
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache  = MiniCache::Store.new()
      @redis  = Storage::RedisClient.new( redis_settings )
      @mbean  = MBean::Client.new( redis: @redis )
      @database   = nil

      if( mysql_host != nil )

        begin
          until( @database != nil )
            @database   = Storage::MySQL.new( mysql_settings )
          end
        rescue => e

          logger.error( e )
        end
      end
    end


    def create_graphite_output( key, values )

      graphite_output = []

      case key
        # Tomcats
      when 'Runtime'
        graphite_output.push( tomcat_runtime( values ) )
      # really not a good idea
#      when 'OperatingSystem'
#        graphite_output.push( tomcatOperatingSystem( values ) )
      when 'Manager'
        graphite_output.push( tomcat_manager( values ) )
      when 'Memory'
        graphite_output.push( tomcat_memory_usage( values ) )
      when 'Threading'
        graphite_output.push( tomcat_threading( values ) )
      when 'GarbageCollectorParNew'
        graphite_output.push( tomcat_gc_parnew( values ) )
      when 'GarbageCollectorConcurrentMarkSweep'
        graphite_output.push( tomcat_gc_concurrentmarksweep( values ) )
      when 'ClassLoading'
        graphite_output.push( tomcat_class_loading( values ) )
      when 'ThreadPool'
        graphite_output.push( tomcat_thread_pool( values ) )

        # CAE
      when 'DataViewFactory'
        graphite_output.push( caeDataViewFactory( values ) )
      when /^CacheClasses/
        graphite_output.push( caeCacheClasses( key, values ) )

        # Content Server
      when 'StoreQueryPool'
        graphite_output.push( contentServerQueryPool( values ) )
      when 'StoreConnectionPool'
        graphite_output.push( contentServerConnectionPool( values ) )
      when 'Server'
        graphite_output.push( contentServerServer( values ) )
      when 'StatisticsJobResult'
        graphite_output.push( contentServerStatisticsJobResult( values ) )
      when 'StatisticsResourceCache'
        graphite_output.push( contentServerStatisticsResourceCache( values ) )

        # Clients
      when 'CapConnection'
        graphite_output.push( clientsCapConnection( values ) )
      when /^MemoryPool*/
        graphite_output.push( clientsMemoryPool( key, values ) )

        # Feeder
      when 'Health'
        graphite_output.push( feederHealth( values ) )
      when 'ProactiveEngine'
        graphite_output.push( feederProactiveEngine( values ) )
      when 'Feeder'
        graphite_output.push( feederFeeder( values ) )
      # currently disabled
      # need information or discusion about it
      when 'TransformedBlobCacheManager'
        graphite_output.push( feederTransformedBlobCacheManager( values ) )

        # Solr
      when /^Solr.*Replication/
        graphite_output.push( solr_replication( values ) )
      when /^Solr.*QueryResultCache/
        graphite_output.push( solr_query_result_cache( values ) )
      when /^Solr.*DocumentCache/
        graphite_output.push( solr_document_cache( values ) )
      when /^Solr.*Select/
        graphite_output.push( solr_select( values ) )
      end

      graphite_output
    end


    def nodes()

      monitored_server()
    end


    def storage_path( host )

      key    = format( 'config-%s', host )
      data   = @cache.get( key )

      result = host

      if( data.nil? )

        identifier  = @database.config( { :short => host, :fqdn => host, :key => 'graphite_identifier' } )

        if( identifier != false && identifier != nil )

          identifier = identifier.dig( 'graphite_identifier' )

          result = identifier if( identifier != nil )

          @cache.set(key, expires_in: 320 ) { MiniCache::Data.new( result ) }
        end

      else
        result = data
      end

      result
    end



    def run( fqdn = nil )

#      logger.debug( "run( #{fqdn} )" )

      # logger.error( 'no node given' )
      return [] if( fqdn == nil )

      data    = nil

      @identifier    = storage_path( fqdn )
      @Server        = fqdn
      graphite_output = []

      data    = @database.discovery_data( { :short => fqdn, :fqdn => fqdn } )

      logger.info( format( 'Host: %s - \'%s\'', fqdn, @identifier ) )

      # no discovery data found
      #
      return graphite_output if( data == nil )

      data.each do |service, d|

        @service_name = service
        @normalized_service_name     = normalize_service( service )

        next if( service.downcase == 'timestamp' )

        logger.info( format( '  - \'%s\' (%s)', service, @normalized_service_name ) )

        cacheKey     = Storage::RedisClient.cache_key( { :host => fqdn, :pre => 'result', :service => service } )

        result = @redis.get( cacheKey )

        case service
        when 'mongodb'

          if( result.is_a?( Hash ) )
            graphite_output.push( databaseMongoDB( result ) )
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'mysql'

          if( result.is_a?( Hash ) )
            graphite_output.push( databaseMySQL( result ) )
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'postgres'

          if( result.is_a?( Hash ) )
            graphite_output.push( databasePostgres( result ) )
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'node-exporter'

          if( result.is_a?( Hash ) )
            graphite_output.push( operatingSystemNodeExporter( result ) )
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'http-status'

          if( result.is_a?( Hash ) )
            graphite_output.push( http_server_status( result ) )
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        else

          if( result != nil && result.is_a?( Array ) )

            result.each do |r|
              key    = r.keys.first
              values = r.values.first

              graphite_output.push( create_graphite_output( key, values ) )

            end
          else
            logger.error( format( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
            logger.error( result.class.to_s )
          end
        end

      end

      graphite_output
    end

  end

end
