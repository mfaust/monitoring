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

    @known_ports = [
      3306,     # mysql
      5432,     # postrgres
      28017,    # mongodb
      38099,
      40099,
      40199,
      40299,
      40399,
      40499,
      40599,
      40699,
      40799,
      40899,
      40999,
      41099,
      41199,
      41299,
      41399,
      42099,
      42199,
      42299,
      42399,
      42499,
      42599,
      42699,
      42799,
      42899,
      42999,
      43099,
      44099,
      45099
    ]

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

        data.push(
          sprintf(
            format,
            @Host,
            @Service,
            m == 'HeapMemoryUsage' ? 'heap_memory' : 'perm_memory',
            'init',
            10,
            init
          )
        )

        data.push(
          sprintf(
            format,
            @Host,
            @Service,
            m == 'HeapMemoryUsage' ? 'heap_memory' : 'perm_memory',
            'max',
            10,
            max
          )
        )

        data.push(
          sprintf(
            format,
            @Host,
            @Service,
            m == 'HeapMemoryUsage' ? 'heap_memory' : 'perm_memory',
            'used',
            10,
            used
          )
        )

        data.push(
          sprintf(
            format,
            @Host,
            @Service,
            m == 'HeapMemoryUsage' ? 'heap_memory' : 'perm_memory',
            'committed',
            10,
            committed
          )
        )
      end

      @log.debug( JSON.pretty_generate( data ) )

    end

  end

  def ParseResult_Threading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : nil
      count  = value['ThreadCount']      ? value['ThreadCount']      : nil

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

    @log.debug( JSON.pretty_generate( data ) )
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

    @log.debug( JSON.pretty_generate( data ) )

  end

  def ParseResult_ClassLoading( data = {} )

    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s/counter-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      loaded      = value['LoadedClassCount']      ? value['LoadedClassCount']      : nil
      totalLoaded = value['TotalLoadedClassCount'] ? value['TotalLoadedClassCount'] : nil
      unloaded    = value['UnloadedClassCount']    ? value['UnloadedClassCount']    : nil

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'class_loading',
          'loaded',
          10,
          loaded
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'class_loading',
          'total',
          10,
          totalLoaded
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'class_loading',
          'unloaded',
          10,
          unloaded
        )
      )

    else


    end

    @log.debug( JSON.pretty_generate( data ) )

  end

  def ParseResult_GCParNew( data = {} )

    @log.debug( data )

  end

  def ParseResult_GCConcurrentMarkSweep( data = {} )

    @log.debug( data )

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

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'cache-hits',
          10,
          cacheHits
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'cache-evicts',
          10,
          cacheEvicts
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'cache-entries',
          10,
          cacheEntries
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'cache-interval',
          10,
          cacheInterval
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'cache-size',
          10,
          cacheSize
        )
      )

      data.push(
        sprintf(
          format,
          @Host,
          @Service,
          'server',
          'sequence-number',
          10,
          reqSeqNumber
        )
      )

    else


    end

    @log.debug( JSON.pretty_generate( data ) )

  end

  def ParseResult_CapConnection( data = {} )

    @log.debug( data )

  end

  def ParseResult_GCParNew( data = {} )

    @log.debug( data )

  end

  def ParseResult_SolrReplication( data = {} )

    @log.debug( data )

  end

  def ParseResult_SolrQueryResultCache( data = {} )

    @log.debug( data )

  end


# StoreConnectionPool
# StoreQueryPool
# StatisticsBlobStoreMethods
# StatisticsJobResult
# StatisticsPublisherMethods
# StatisticsResource
# StatisticsResourceCache
# StatisticsTextStoreMethods




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

#         @log.debug( sprintf( 'read file \'%s\'', file ) )

        data = JSON.parse( File.read( file ) )

        data.each do |service, data|

          port = data['port']

          @Service = service
          @Port    = port

#           @log.debug( sprintf( ' service \'%s\' : %s', service, port ) )

          bulkResults = sprintf( '%s/bulk_%s.result', dir_path, port )

          if( File.exist?( bulkResults ) == true )
#             @log.debug( sprintf( ' read bulk results from file \'%s\'', bulkResults ) )

            bulk = JSON.parse( File.read( bulkResults ) )

#             @log.debug( bulk.count )

            # @log.debug( JSON.pretty_generate( bulk ) )
            # @log.debug( JSON.pretty_generate( bulk[0] ) )

            bulk.each do |result|

              result.each do |k,v|
#                 @log.debug( sprintf( '   result for \'%s\'', k ) )

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
                end


              end
            end

          end

        end
      end
    end

  end

end
