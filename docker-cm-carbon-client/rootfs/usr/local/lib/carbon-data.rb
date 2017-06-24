#!/usr/bin/ruby
#
# 14.09.2016 - Bodo Schulz
#
#
# v1.4.2

# -----------------------------------------------------------------------------

require 'time'
require 'date'
require 'time_difference'
require 'json'
require 'filesize'
require 'fileutils'

require_relative 'logging'
require_relative 'cache'
require_relative 'storage'
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

      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)             || 6379

      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      version             = CarbonData::VERSION # '2.0.0'
      date                = CarbonData::DATE    # '2017-04-13'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - CarbonData' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
      if( mysqlHost != nil )
        logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      end
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache  = Cache::Store.new()
      @redis  = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
      @mbean  = MBean::Client.new( { :redis => @redis } )
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
    end


    def createGraphiteOutput( key, values )

      graphiteOutput = Array.new()

      case key
        # Tomcats
      when 'Runtime'
        graphiteOutput.push( self.tomcatRuntime( values ) )
      # really not a good idea
#      when 'OperatingSystem'
#        graphiteOutput.push( self.tomcatOperatingSystem( values ) )
      when 'Manager'
        graphiteOutput.push( self.tomcatManager( values ) )
      when 'Memory'
        graphiteOutput.push( self.tomcatMemoryUsage( values ) )
      when 'Threading'
        graphiteOutput.push( self.tomcatThreading( values ) )
      when 'GarbageCollectorParNew'
        graphiteOutput.push( self.tomcatGCParNew( values ) )
      when 'GarbageCollectorConcurrentMarkSweep'
        graphiteOutput.push( self.tomcatGCConcurrentMarkSweep( values ) )
      when 'ClassLoading'
        graphiteOutput.push( self.tomcatClassLoading( values ) )
      when 'ThreadPool'
        graphiteOutput.push( self.tomcatThreadPool( values ) )

        # CAE
      when 'DataViewFactory'
        graphiteOutput.push( self.caeDataViewFactory( values ) )
      when /^CacheClasses/
        graphiteOutput.push( self.caeCacheClasses( key, values ) )

        # Content Server
      when 'StoreQueryPool'
        graphiteOutput.push( self.contentServerQueryPool( values ) )
      when 'StoreConnectionPool'
        graphiteOutput.push( self.contentServerConnectionPool( values ) )
      when 'Server'
        graphiteOutput.push( self.contentServerServer( values ) )
      when 'StatisticsJobResult'
        graphiteOutput.push( self.contentServerStatisticsJobResult( values ) )
      when 'StatisticsResourceCache'
        graphiteOutput.push( self.contentServerStatisticsResourceCache( values ) )

        # Clients
      when 'CapConnection'
        graphiteOutput.push( self.clientsCapConnection( values ) )
      when /^MemoryPool*/
        graphiteOutput.push( self.clientsMemoryPool( key, values ) )

        # Feeder
      when 'Health'
        graphiteOutput.push( self.feederHealth( values ) )
      when 'ProactiveEngine'
        graphiteOutput.push( self.feederProactiveEngine( values ) )
      when 'Feeder'
        graphiteOutput.push( self.feederFeeder( values ) )
      # currently disabled
      # need information or discusion about it
      when 'TransformedBlobCacheManager'
        graphiteOutput.push( self.feederTransformedBlobCacheManager( values ) )

        # Solr
      when /^Solr.*Replication/
        graphiteOutput.push( self.solrReplication( values ) )
      when /^Solr.*QueryResultCache/
        graphiteOutput.push( self.solrQueryResultCache( values ) )
      when /^Solr.*DocumentCache/
        graphiteOutput.push( self.solrDocumentCache( values ) )
      when /^Solr.*Select/
        graphiteOutput.push( self.solrSelect( values ) )
      end

      return graphiteOutput
    end


    def nodes()

      return self.monitoredServer()
    end


    def storagePath( host )

      key    = sprintf( 'config-%s', host )
      data   = @cache.get( key )

      result = host

      if( data == nil )

        identifier  = @database.config( { :short => host, :fqdn => host, :key => 'graphite_identifier' } )

        if( identifier != false && identifier != nil )

          identifier = identifier.dig( 'graphite_identifier' )

          if( identifier != nil )
            result     = identifier
          end

          @cache.set( key, expiresIn: 320 ) { Cache::Data.new( result ) }
        end

      else

        result = data
      end

      return result
    end



    def run( fqdn = nil )

#       logger.debug( "run( #{fqdn} )" )

      if( fqdn == nil )
        logger.error( 'no node given' )

        return []
      end

      data    = nil

      @identifier    = self.storagePath( fqdn )
      @Server        = fqdn
      graphiteOutput = Array.new()

      data    = @database.discoveryData( { :short => fqdn, :fqdn => fqdn } )

      # no discovery data found
      #
      if( data == nil )
        logger.warn( 'no discovery data found' )
        return graphiteOutput
      end

      data.each do |service, d|

        @serviceName = service
        @Service     = self.normalizeService( service )

        if( service.downcase == 'timestamp' )
          next
        end

        logger.info( sprintf( 'Host: %s - \'%s\' (%s)', fqdn, service, @Service ) )

        cacheKey     = Storage::RedisClient.cacheKey( { :host => fqdn, :pre => 'result', :service => service } )

        result = @redis.get( cacheKey )

        case service
        when 'mongodb'

          if( result.is_a?( Hash ) )
            graphiteOutput.push( self.databaseMongoDB( result ) )
          else
            logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'mysql'

          if( result.is_a?( Hash ) )
            graphiteOutput.push( self.databaseMySQL( result ) )
          else
            logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'postgres'

          if( result.is_a?( Hash ) )
            graphiteOutput.push( self.databasePostgres( result ) )
          else
            logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'node-exporter'

          if( result.is_a?( Hash ) )
            graphiteOutput.push( self.operatingSystemNodeExporter( result ) )
          else
            logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        when 'http-status'

          if( result.is_a?( Hash ) )
            graphiteOutput.push( self.http_server_status( result ) )
          else
            logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @identifier, service ) )
          end

        else

          if( result != nil )

            result.each do |r|
              key    = r.keys.first
              values = r.values.first

              graphiteOutput.push( self.createGraphiteOutput( key, values ) )

            end
          end
        end

      end

      return graphiteOutput
    end

  end

end
