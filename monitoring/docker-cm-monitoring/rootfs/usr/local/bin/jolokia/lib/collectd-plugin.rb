#
#

# require './lib/collectd_plugin_graphite'


class CollecdPlugin

  attr_reader :status, :message, :services

  def initialize

    file = File.open( '/tmp/monitor-collectd.log', File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @cacheDirectory = '/var/cache/monitoring'

    @interval       = 10 # in seconds
  end


  def output( data = [] )

    data.each do |d|
      puts d
    end

  end


  def ParseResult_Memory( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      ['HeapMemoryUsage', 'NonHeapMemoryUsage'].each do |m|

        init      = value[m]['init']
        max       = value[m]['max']
        used      = value[m]['used']
        committed = value[m]['committed']

        case m
        when 'HeapMemoryUsage'
          type = 'heap_memory'
        else
          type = 'perm_memory'
        end

        data.push( sprintf( format, @Host, @Service, type, 'init'     , @interval, init ) )
        data.push( sprintf( format, @Host, @Service, type, 'max'      , @interval, max ) )
        data.push( sprintf( format, @Host, @Service, type, 'used'     , @interval, used ) )
        data.push( sprintf( format, @Host, @Service, type, 'committed', @interval, committed ) )
      end

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

    end

  end


  def ParseResult_Threading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : nil
      count  = value['ThreadCount']      ? value['ThreadCount']      : nil

      data.push( sprintf( format, @Host, @Service, 'threading', 'peak' , @interval, peak ) )
      data.push( sprintf( format, @Host, @Service, 'threading', 'count', @interval, count ) )

    else


    end

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_ThreadPool( data = {} )

    return

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : nil
      count  = value['ThreadCount']      ? value['ThreadCount']      : nil

#         "activeCount": 0,
#         "queueSize": 0,
#         "modelerType": "org.apache.catalina.core.StandardThreadExecutor",
#         "largestPoolSize": 20,
#         "poolSize": 20,
#         "maxIdleTime": 60000,
#         "threadPriority": 5,
#         "daemon": true,
#         "minSpareThreads": 20,
#         "maxQueueSize": 2147483647,
#         "stateName": "STARTED",
#         "namePrefix": "catalina-exec-",
#         "name": "tomcatThreadPool",
#         "corePoolSize": 20,
#         "completedTaskCount": 30,
#         "maxThreads": 200,
#         "prestartminSpareThreads": false,
#         "threadRenewalDelay": 1000



      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'threading',
          'peak',
          10,
          peak
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'threading',
          'count',
          10,
          count
        )
      )

    else


    end

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_ClassLoading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_GCParNew( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen' ].each do |type|

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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_GCConcurrentMarkSweep( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen' ].each do |type|

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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_Server( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

      data.push( sprintf( format, @Host, @Service, 'server', 'cache-hits'     , @interval, cacheHits ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache-evicts'   , @interval, cacheEvicts ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache-entries'  , @interval, cacheEntries ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache-interval' , @interval, cacheInterval ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'cache-size'     , @interval, cacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'server', 'sequence-number', @interval, reqSeqNumber ) )

    else


    end

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_CapConnection( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      blobCacheSize    = value['BlobCacheSize']     ? value['BlobCacheSize']     : nil
      blobCacheLevel   = value['BlobCacheLevel']    ? value['BlobCacheLevel']    : nil
      blobCacheFaults  = value['BlobCacheFaults']   ? value['BlobCacheFaults']   : nil
      heapCacheSize    = value['HeapCacheSize']     ? value['HeapCacheSize']     : nil
      heapCacheLevel   = value['HeapCacheLevel']    ? value['HeapCacheLevel']    : nil
      heapCacheFaults  = value['HeapCacheFaults']   ? value['HeapCacheFaults']   : nil

      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'size' , @interval, blobCacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'level', @interval, blobCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, 'blob_cache', 'fault', @interval, blobCacheFaults ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'size' , @interval, heapCacheSize ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'level', @interval, heapCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, 'heap_cache', 'fault', @interval, heapCacheFaults ) )

    else


    end

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_SolrReplication( data = {} )

    @log.debug( data )

  end


  def ParseResult_SolrQueryResultCache( data = {} )

    @log.debug( data )

  end


  def ParseResult_ConnectionPool( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_QueryPool( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_StatisticsBlobStoreMethods( data = {} )

    # was für komische Werte kommen da aus JMX raus?
    # müssen wir klären

  end


  def ParseResult_StatisticsJobResult( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

  end


  def ParseResult_StatisticsResourceCache( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
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

#       @log.debug( JSON.pretty_generate( data ) )

      self.output( data )

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


    dataFile = 'mergedHostData.json'

    data = Hash.new()

    monitoredServer.each do |h|

      @Host = h

      @log.info( sprintf( 'Host: %s', h ) )

      dir_path  = sprintf( '%s/%s', @cacheDirectory, h )

      file = sprintf( '%s/%s', dir_path, dataFile )

      if( File.exist?( file ) == true )

        data = JSON.parse( File.read( file ) )

        data.each do |service, data|

          port = data['port']

          @Service = service
          @Port    = port

          bulkResults = sprintf( '%s/bulk_%s.result', dir_path, port )

          if( File.exist?( bulkResults ) == true )

            bulk = JSON.parse( File.read( bulkResults ) )

            bulk.each do |result|

              result.each do |k,v|

                case k
                when 'Memory'
                  self.ParseResult_Memory( v )
                when 'Threading'
                  self.ParseResult_Threading( v )
                when 'ExecutortomcatThreadPool'
                  self.ParseResult_ThreadPool( v )
                when 'ClassLoading'
                  self.ParseResult_ClassLoading( v )
                when 'Server'
                  self.ParseResult_Server( v )
                when 'CapConnection'
                  self.ParseResult_CapConnection( v )
                when 'StoreConnectionPool'
                  self.ParseResult_ConnectionPool( v )
                when 'StoreQueryPool'
                  self.ParseResult_QueryPool( v )
                when 'StatisticsJobResult'
                  self.ParseResult_StatisticsJobResult( v )
                when 'StatisticsResourceCache'
                  self.ParseResult_StatisticsResourceCache( v )
                when 'GarbageCollectorParNew'
                  self.ParseResult_GCParNew( v )
                when 'GarbageCollectorConcurrentMarkSweep'
                  self.ParseResult_GCConcurrentMarkSweep( v )
                end


              end
            end

          end

        end
      end
    end

  end

end
