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
require_relative 'storage'
require_relative 'mbean'

require_relative 'carbon-data/utils'
require_relative 'carbon-data/tomcat'
require_relative 'carbon-data/cae'
require_relative 'carbon-data/content-server'
require_relative 'carbon-data/clients'
require_relative 'carbon-data/feeder'
require_relative 'carbon-data/solr'
require_relative 'carbon-data/database/mongodb'
require_relative 'carbon-data/database/mysql'
require_relative 'carbon-data/database/postgres'
require_relative 'carbon-data/operating-system/node-exporter'

# -----------------------------------------------------------------------------

class Time
  def add_minutes(m)
    self + (60 * m)
  end
end

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
    include CarbonData::Database::MongoDB
    include CarbonData::Database::MySQL
    include CarbonData::Database::Postgres
    include CarbonData::OperatingSystem::NodeExporter

    def initialize( params = {} )

      memcacheHost   = params.dig( :memcache, :host )
      memcachePort   = params.dig( :memcache, :port )

#       @interval      = params[:interval]       ? params[:interval]       : 15
#       @interval      = @interval.to_i

      version              = '1.99.8'
      date                 = '2017-03-03'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - CarbonData' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
#       logger.info( "  configured interval #{@interval}" )
      logger.info( '  used Services:' )
      logger.info( "    - memcache     : #{memcacheHost}:#{memcachePort}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @db          = Storage::Database.new()
      @mc          = Storage::Memcached.new( { :host => memcacheHost, :port => memcachePort } )
      @mbean       = MBean::Client.new( { :memcache => @mc } )

    end


    def createGraphiteOutput( key, values )

#      logger.debug( sprintf( 'createGraphiteOutput( %s, %s )', key, values ) )

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
  #     when 'MemoryPoolCMSOldGen'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
  #     when 'MemoryPoolCodeCache'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
  #     when 'MemoryPoolCompressedClassSpace'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
  #     when 'MemoryPoolMetaspace'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
  #     when 'MemoryPoolParEdenSpace'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
  #     when 'MemoryPoolParSurvivorSpace'
  #       graphiteOutput.push(self.ParseResult_MemoryPool( values ) )

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


    def run()

      monitoredServer = self.monitoredServer()
      data            = nil

#       logger.debug( "#{monitoredServer.keys}" )

      monitoredServer.each do |h,d|

        @Host = h
        graphiteOutput = Array.new()

        logger.info( sprintf( 'Host: %s', h ) )

        # to improve performance, read initial discovery Data from Database and store them into Memcache (or Redis)
        key       = Storage::Memcached.cacheKey( { :host => h, :pre => 'discovery' } )
        data      = @mc.get( key )

        # recreate the cache every 10 minutes
        if ( data != nil )

          today     = Time.now().to_s
          timestamp = data.dig( 'timestamp' ) || Time.now().to_s

          x = self.timeParser( today, timestamp )
#           logger.debug( x )

          if( x[:minutes] >= 10 )
            data = nil
          end

        end

        if( data == nil )

          data = @db.discoveryData( { :ip => h, :short => h } )
#           logger.debug( data )

          if( data == nil )
            next
          end

          data = data[h]
          data['timestamp'] = Time.now().to_s

          if( data == nil )
            next
          else
            @mc.set( key, data )
          end

        end

        # no discovery data found
        if( data == nil )
          next
        end

        data.each do |service, d|

          @serviceName = service
          @Service     = self.normalizeService( service )

          if( service.downcase == 'timestamp' )
            next
          end

          logger.info( sprintf( '  - %s (%s)', service, @Service ) )

          cacheKey     = Storage::Memcached.cacheKey( { :host => h, :pre => 'result', :service => service } )

          result = @mc.get( cacheKey )

          case service
          when 'mongodb'

            if( result.is_a?( Hash ) )
              graphiteOutput.push( self.databaseMongoDB( result ) )
            else
              logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @Host, service ) )
            end

          when 'mysql'

            if( result.is_a?( Hash ) )
              graphiteOutput.push( self.databaseMySQL( result ) )
            else
              logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @Host, service ) )
            end

          when 'postgres'

            if( result.is_a?( Hash ) )
              graphiteOutput.push( self.databasePostgres( result ) )
            else
              logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @Host, service ) )
            end

          when 'node_exporter'

            if( result.is_a?( Hash ) )
              graphiteOutput.push( self.operatingSystemNodeExporter( result ) )
            else
              logger.error( sprintf( 'result is not valid (Host: \'%s\' :: service \'%s\')', @Host, service ) )
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

end
