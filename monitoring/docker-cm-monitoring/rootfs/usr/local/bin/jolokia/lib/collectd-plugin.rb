#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v0.9.3

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'filesize'

require_relative 'tools'

# -----------------------------------------------------------------------------

class CollecdPlugin

  attr_reader :status, :message, :services

  def initialize( settings = {} )

    @logDirectory   = settings['log_dir']      ? settings['log_dir']      : '/tmp'
    @cacheDirectory = settings['cache_dir']    ? settings['cache_dir']    : '/var/tmp/monitoring'
    @interval       = settings['interval']     ? settings['interval']     : 15

    logFile = sprintf( '%s/collectd.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    version              = '1.0.0'
    date                 = '2016-08-12'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CollectdPlugin' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( "  cache directory located at #{@cacheDirectory}" )
    @log.info( "  configured interval #{@interval}" )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

  end


  def output( data = [] )

    data.each do |d|
      puts d
    end

  end


  def solrCore( mbean )

    regex = /
      ^                     # Starting at the front of the string
      solr\/                #
      (?<core>.+[a-zA-Z]):  #
      (.*)                  #
      type=                 #
      (?<type>.+[a-zA-Z])   #
      $
    /x

    parts          = mbean.match( regex )
    return sprintf( '%s_core', "#{parts['core']}".strip.tr( '. ', '' ).downcase )

  end


  def normalizeService( service )

    # normalize service names for grafana
    case service
    when 'content-management-server'
      service = 'CMS'
    when 'master-live-server'
      service = 'MLS'
    when 'repication-live-server'
      service = 'RLS'
    when 'workflow-server'
      service = 'WFS'
    when /^cae-live/
      service = 'CAE_LIVE'
#    when 'solr-master'
#      service = 'SOLR_MASTER'
#    when 'solr-slave'
#      service = 'SOLR_SLAVE'
    when 'caefeeder-live'
      service = 'FEEDER_LIVE'
    when 'caefeeder-preview'
      service = 'FEEDER_PREV'
    end

    return service.tr('-', '_').upcase

  end


  def ParseResult_Memory( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      ['HeapMemoryUsage', 'NonHeapMemoryUsage'].each do |m|

        init      = value[m]['init']
        max       = value[m]['max']
        used      = value[m]['used']
        committed = value[m]['committed']

        percent   = ( 100 * used / committed )

        case m
        when 'HeapMemoryUsage'
          type = 'heap_memory'
        else
          type = 'perm_memory'
        end

        data.push( sprintf( format, @Host, @Service, type, 'init'        , @interval, init ) )
        data.push( sprintf( format, @Host, @Service, type, 'max'         , @interval, max ) )
        data.push( sprintf( format, @Host, @Service, type, 'used'        , @interval, used ) )
        data.push( sprintf( format, @Host, @Service, type, 'used_percent', @interval, percent ) )
        data.push( sprintf( format, @Host, @Service, type, 'committed'   , @interval, committed ) )
      end

      return data

    end

  end


  def ParseResult_Threading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : nil
      count  = value['ThreadCount']      ? value['ThreadCount']      : nil

      data.push( sprintf( format, @Host, @Service, 'threading', 'peak' , @interval, peak ) )
      data.push( sprintf( format, @Host, @Service, 'threading', 'count', @interval, count ) )

    else

    end

    return data

  end


  def ParseResult_ThreadPool( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_ClassLoading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      loaded      = value['LoadedClassCount']      ? value['LoadedClassCount']      : nil
      totalLoaded = value['TotalLoadedClassCount'] ? value['TotalLoadedClassCount'] : nil
      unloaded    = value['UnloadedClassCount']    ? value['UnloadedClassCount']    : nil

      data.push( sprintf( format, @Host, @Service, 'class_loading', 'loaded'  , @interval, loaded ) )
      data.push( sprintf( format, @Host, @Service, 'class_loading', 'total'   , @interval, totalLoaded ) )
      data.push( sprintf( format, @Host, @Service, 'class_loading', 'unloaded', @interval, unloaded ) )

    else


    end

    return data

  end


  def ParseResult_GCParNew( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        data.push( sprintf( format, @Host, @Service, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|

          case gc
          when 'memoryUsageBeforeGc'
            gc_type = 'before'
          when 'memoryUsageAfterGc'
            gc_type = 'after'
          end

          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|

            if( lastGcInfo[gc][type] )
              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil

              type      = type.strip.tr( ' ', '_' ).downcase

              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
            end
         end
        end
      end
    end

    return data

  end


  def ParseResult_GCConcurrentMarkSweep( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        data.push( sprintf( format, @Host, @Service, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|

          case gc
          when 'memoryUsageBeforeGc'
            gc_type = 'before'
          when 'memoryUsageAfterGc'
            gc_type = 'after'
          end

          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|

            if( lastGcInfo[gc][type] )
              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil

              type      = type.strip.tr( ' ', '_' ).downcase

              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_markseep_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_markseep_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_markseep_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
              data.push( sprintf( format, @Host, @Service, sprintf( 'gc_markseep_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
            end
         end
        end
      end
    end

    return data

  end


  def ParseResult_Server( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      cacheHits        = value['ResourceCacheHits']         ? value['ResourceCacheHits']         : nil
      cacheEvicts      = value['ResourceCacheEvicts']       ? value['ResourceCacheEvicts']       : nil
      cacheEntries     = value['ResourceCacheEntries']      ? value['ResourceCacheEntries']      : nil
      cacheInterval    = value['ResourceCacheInterval']     ? value['ResourceCacheInterval']     : nil
      cacheSize        = value['ResourceCacheSize']         ? value['ResourceCacheSize']         : nil
      reqSeqNumber     = value['RepositorySequenceNumber']  ? value['RepositorySequenceNumber']  : nil
      connectionCount  = value['ConnectionCount']           ? value['ConnectionCount']           : nil
      runlevel         = value['RunLevel']                  ? value['RunLevel']                  : nil
      uptime           = value['Uptime']                    ? value['Uptime']                    : nil

      data.push( sprintf( format, @Host, @Service, 'server', 'cache_hits'     , @interval, cacheHits ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache_evicts'   , @interval, cacheEvicts ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache_entries'  , @interval, cacheEntries ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache_interval' , @interval, cacheInterval ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache_size'     , @interval, cacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'sequence_number', @interval, reqSeqNumber ) )

    else


    end

    return data

  end


  def ParseResult_Feeder( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )
      pendingEvents           = value['PendingEvents']              ? value['PendingEvents']              : nil
      indexDocuments          = value['IndexDocuments']             ? value['IndexDocuments']             : nil
      indexContentDocuments   = value['IndexContentDocuments']      ? value['IndexContentDocuments']      : nil
      currentPendingDocuments = value['CurrentPendingDocuments']    ? value['CurrentPendingDocuments']    : nil

      data.push( sprintf( format, @Host, @Service, 'server', 'pending_events'            , @interval, pendingEvents ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'index_documents'           , @interval, indexDocuments ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )
    end

    return data

  end


  def ParseResult_CacheClasses( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )
      capacity  = value['Capacity']    ? value['Capacity']    : nil
      evaluated = value['Evaluated']   ? value['Evaluated']   : nil
      evicted   = value['Evicted']     ? value['Evicted']     : nil
      inserted  = value['Inserted']    ? value['Inserted']    : nil
      removed   = value['Removed']     ? value['Removed']     : nil
      level     = value['Level']       ? value['Level']       : nil

      data.push( sprintf( format, @Host, @Service, 'content_beans', 'level'     , @interval, level ) )
      data.push( sprintf( format, @Host, @Service, 'content_beans', 'capacity'  , @interval, capacity ) )
      data.push( sprintf( format, @Host, @Service, 'content_beans', 'evaluated' , @interval, evaluated ) )
      data.push( sprintf( format, @Host, @Service, 'content_beans', 'evicted'   , @interval, evicted ) )
      data.push( sprintf( format, @Host, @Service, 'content_beans', 'inserted'  , @interval, inserted ) )
      data.push( sprintf( format, @Host, @Service, 'content_beans', 'removed'   , @interval, removed ) )
    end

    return data

  end


  def ParseResult_ProactiveEngine( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      maxEntries     = value['KeysCount']     ? value['KeysCount']     : 0  # max feeder entries
      currentEntries = value['ValuesCount']   ? value['ValuesCount']   : 0  # current feeder entries
      diffEntries    = ( maxEntries - currentEntries ).to_i

      data.push( sprintf( format, @Host, @Service, 'feeder', 'max'      , @interval, maxEntries ) )
      data.push( sprintf( format, @Host, @Service, 'feeder', 'current'  , @interval, currentEntries ) )
      data.push( sprintf( format, @Host, @Service, 'feeder', 'diff'     , @interval, diffEntries ) )
    end

    return data
  end


  def ParseResult_CapConnection( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      blobCacheSize    = value['BlobCacheSize']     ? value['BlobCacheSize']     : nil
      blobCacheLevel   = value['BlobCacheLevel']    ? value['BlobCacheLevel']    : nil
      blobCacheFaults  = value['BlobCacheFaults']   ? value['BlobCacheFaults']   : nil
      blobCachePercent = ( 100 * blobCacheLevel.to_i / blobCacheSize.to_i ).to_i

      heapCacheSize    = value['HeapCacheSize']     ? value['HeapCacheSize']     : nil
      heapCacheLevel   = value['HeapCacheLevel']    ? value['HeapCacheLevel']    : nil
      heapCacheFaults  = value['HeapCacheFaults']   ? value['HeapCacheFaults']   : nil
      heapCachePercent = ( 100 * heapCacheLevel.to_i / heapCacheSize.to_i ).to_i

      suSessions       = value['NumberOfSUSessions']   ? value['NumberOfSUSessions']   : nil


      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'size'        , @interval, blobCacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'used'        , @interval, blobCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'fault'       , @interval, blobCacheFaults ) )
      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'used_percent', @interval, blobCachePercent ) )

      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'size'        , @interval, heapCacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'used'        , @interval, heapCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'fault'       , @interval, heapCacheFaults ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'used_percent', @interval, heapCachePercent ) )

      data.push( sprintf( format, @Host, @Service, 'su_sessions', 'sessions'   , @interval, suSessions ) )

    else


    end

    return data

  end


  def ParseResult_SolrReplication( data = {} )

    value  = data['value']            ? data['value']            : nil
    mbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( mbean )

    if( value != nil )

      generation        = value['generation']        ? value['generation']        : nil
      isMaster          = value['isSlave']           ? value['isSlave']           : nil
      isSlave           = value['isMaster']          ? value['isMaster']          : nil
      indexVersion      = value['indexVersion']      ? value['indexVersion']      : nil
      requests          = value['requests']          ? value['requests']          : nil
      medianRequestTime = value['medianRequestTime'] ? value['medianRequestTime'] : nil
      errors            = value['errors']            ? value['errors']            : nil
      indexSize         = value['indexSize']         ? value['indexSize']         : nil
      # achtung!
      # indexSize ist irrsinnigerweise als human readable ausgeführt worden!
      indexSize         = Filesize.from( indexSize ).to_i

      data.push( sprintf( format, @Host, @Service, solrCore, 'index_size', @interval, indexSize.to_s ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'index'     , @interval, indexVersion ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'errors    ', @interval, errors ) )

    end

    return data

  end


  def ParseResult_SolrQueryResultCache( data = {} )

    value  = data['value']            ? data['value']            : nil
    mbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( mbean )

    if( value != nil )

      warmupTime           = value['warmupTime']           ? value['warmupTime']           : nil
      lookups              = value['lookups']              ? value['lookups']              : nil
      evictions            = value['evictions']            ? value['evictions']            : nil
      inserts              = value['inserts']              ? value['inserts']              : nil
      hits                 = value['hits']                 ? value['hits']                 : nil
      size                 = value['size']                 ? value['size']                 : nil
      hitratio             = value['hitratio']             ? value['hitratio']             : nil
      cumulative_inserts   = value['cumulative_inserts']   ? value['cumulative_inserts']   : nil
      cumulative_hits      = value['cumulative_hits']      ? value['cumulative_hits']      : nil
      cumulative_evictions = value['cumulative_evictions'] ? value['cumulative_evictions'] : nil
      cumulative_hitratio  = value['cumulative_hitratio']  ? value['cumulative_hitratio']  : nil
      cumulative_lookups   = value['cumulative_lookups']   ? value['cumulative_lookups']   : nil

      data.push( sprintf( format, @Host, @Service, solrCore, 'warmupTime'  , @interval, warmupTime ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'lookups'     , @interval, lookups ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'evictions'   , @interval, evictions ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'inserts'     , @interval, inserts ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'hits'        , @interval, hits ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'size'        , @interval, size ) )
      data.push( sprintf( format, @Host, @Service, solrCore, 'hitratio'    , @interval, hitratio ) )

    end

    return data

  end


  def ParseResult_ConnectionPool( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      open   = value['OpenConnections']  ? value['OpenConnections']  : nil
      max    = value['MaxConnections']   ? value['MaxConnections']   : nil
      idle   = value['IdleConnections']  ? value['IdleConnections']  : nil
      busy   = value['BusyConnections']  ? value['BusyConnections']  : nil
      min    = value['MinConnections']   ? value['MinConnections']   : nil

      data.push( sprintf( format, @Host, @Service, 'connection_pool', 'open', @interval, open ) )
      data.push( sprintf( format, @Host, @Service, 'connection_pool', 'max' , @interval, max ) )
      data.push( sprintf( format, @Host, @Service, 'connection_pool', 'idle', @interval, idle ) )
      data.push( sprintf( format, @Host, @Service, 'connection_pool', 'busy', @interval, busy ) )
      data.push( sprintf( format, @Host, @Service, 'connection_pool', 'min' , @interval, min ) )

    else


    end

    return data

  end


  def ParseResult_QueryPool( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      executorsRunning = value['RunningExecutors'] ? value['RunningExecutors'] : nil
      executorsIdle    = value['IdleExecutors']    ? value['IdleExecutors']    : nil
      queriesMax       = value['MaxQueries']       ? value['MaxQueries']       : nil
      queriesWaiting   = value['WaitingQueries']   ? value['WaitingQueries']   : nil


      data.push( sprintf( format, @Host, @Service, 'query_pool', 'executors_running', @interval, executorsRunning ) )
      data.push( sprintf( format, @Host, @Service, 'query_pool', 'executors_idle'   , @interval, executorsIdle ) )
      data.push( sprintf( format, @Host, @Service, 'query_pool', 'queries_max'      , @interval, queriesMax ) )
      data.push( sprintf( format, @Host, @Service, 'query_pool', 'queries_waiting'  , @interval, queriesWaiting ) )

    else


    end

    return data

  end


  def ParseResult_StatisticsBlobStoreMethods( data = {} )

    # was für komische Werte kommen da aus JMX raus?
    # müssen wir klären

  end


  def ParseResult_StatisticsJobResult( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      failed        = value['Failed']        ? value['Failed']        : nil
      successful    = value['Successful']    ? value['Successful']    : nil
      unrecoverable = value['Unrecoverable'] ? value['Unrecoverable'] : nil

      data.push( sprintf( format, @Host, @Service, 'stats_jobresult', 'failed'       , @interval, failed ) )
      data.push( sprintf( format, @Host, @Service, 'stats_jobresult', 'successful'   , @interval, successful ) )
      data.push( sprintf( format, @Host, @Service, 'stats_jobresult', 'unrecoverable', @interval, unrecoverable ) )

    else

    end

    return data

  end


  def ParseResult_StatisticsResourceCache( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/cm7_counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      size     = value['CacheSize']     ? value['CacheSize']     : nil
      removed  = value['CacheRemoved']  ? value['CacheRemoved']  : nil
      faults   = value['CacheFaults']   ? value['CacheFaults']   : nil
      misses   = value['CacheMisses']   ? value['CacheMisses']   : nil
      hits     = value['CacheHits']     ? value['CacheHits']     : nil


      data.push( sprintf( format, @Host, @Service, 'stats_resourcecache', 'size'   , @interval, size ) )
      data.push( sprintf( format, @Host, @Service, 'stats_resourcecache', 'removed', @interval, removed ) )
      data.push( sprintf( format, @Host, @Service, 'stats_resourcecache', 'faults' , @interval, faults ) )
      data.push( sprintf( format, @Host, @Service, 'stats_resourcecache', 'misses' , @interval, misses ) )
      data.push( sprintf( format, @Host, @Service, 'stats_resourcecache', 'hits'   , @interval, hits ) )

    else

    end

    return data

  end


  def ParseResult_StatisticsBlobStoreMethods( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_StatisticsResource( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_StatisticsTextStoreMethods( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_StatisticsPublisherMethods( data = {} )

    # was für komische
    # müssen wir klären

  end



  def run()

    monitoredServer = monitoredServer( @cacheDirectory )
    dataFile        = 'mergedHostData.json'
    data            = Hash.new()

    monitoredServer.each do |h|

      @Host = h

      @log.info( sprintf( 'Host: %s', h ) )

      dir_path  = sprintf( '%s/%s', @cacheDirectory, h )

      file = sprintf( '%s/%s', dir_path, dataFile )

      if( File.exist?( file ) == true )

        data = JSON.parse( File.read( file ) )

        data.each do |service, data|

          port = data['port']

          @Service = self.normalizeService( service )
          @Port    = port

          bulkResults = sprintf( '%s/bulk_%s.result', dir_path, port )

          @log.debug( bulkResults )

          if( File.exist?( bulkResults ) == true )

            graphiteOutput  = Array.new()

            bulk = JSON.parse( File.read( bulkResults ) )

            bulk.each do |result|

              result.each do |k,v|

                case k
                when 'Memory'
                  graphiteOutput.push( self.ParseResult_Memory( v ) )
                when 'Threading'
                  graphiteOutput.push( self.ParseResult_Threading( v ) )
#                when 'ExecutortomcatThreadPool'
#                  graphiteOutput.push( self.ParseResult_ThreadPool( v ) )
                when 'ClassLoading'
                  graphiteOutput.push( self.ParseResult_ClassLoading( v ) )
                when 'Server'
                  graphiteOutput.push( self.ParseResult_Server( v ) )
                when 'ProactiveEngine'
                  graphiteOutput.push( self.ParseResult_ProactiveEngine( v ) )
                when 'Feeder'
                  graphiteOutput.push( self.ParseResult_Feeder( v ) )
                when 'CacheClasses'
                  graphiteOutput.push( self.ParseResult_CacheClasses( v ) )
                when 'CapConnection'
                  graphiteOutput.push( self.ParseResult_CapConnection( v ) )
                when 'StoreConnectionPool'
                  graphiteOutput.push( self.ParseResult_ConnectionPool( v ) )
                when 'StoreQueryPool'
                  graphiteOutput.push( self.ParseResult_QueryPool( v ) )
                when 'StatisticsJobResult'
                  graphiteOutput.push( self.ParseResult_StatisticsJobResult( v ) )
                when 'StatisticsResourceCache'
                  graphiteOutput.push( self.ParseResult_StatisticsResourceCache( v ) )
                when 'GarbageCollectorParNew'
                  graphiteOutput.push( self.ParseResult_GCParNew( v ) )
                when 'GarbageCollectorConcurrentMarkSweep'
                  graphiteOutput.push( self.ParseResult_GCConcurrentMarkSweep( v ) )
                when /^Solr.*Replication/
                  graphiteOutput.push( self.ParseResult_SolrReplication( v ) )
                when /^Solr.*QueryResultCache/
                  graphiteOutput.push( self.ParseResult_SolrQueryResultCache( v ) )
                end
              end
            end

            self.output( graphiteOutput )

          end

        end
      end
    end

  end

end
