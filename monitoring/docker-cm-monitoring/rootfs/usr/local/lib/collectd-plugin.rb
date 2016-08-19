#!/usr/bin/ruby
#
# 16.08.2016 - Bodo Schulz
#
#
# v1.0.2

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'filesize'
require 'fileutils'

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
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    if( File.exists?( logFile ) )
      FileUtils.chmod( 0666, logFile )
      FileUtils.chown( 'nobody', 'nobody', logFile )
    end

    version              = '1.0.2'
    date                 = '2016-08-16'

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
    return sprintf( 'core_%s', "#{parts['core']}".strip.tr( '. ', '' ).downcase )

  end

  def ParseResult_mongoDB( value = {} )

    format = 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      uptime         = value['uptime']

      asserts        = value['asserts']       ? value['asserts']       : nil
      connections    = value['connections']   ? value['connections']   : nil
      network        = value['network']       ? value['network']       : nil
      opcounters     = value['opcounters']    ? value['opcounters']    : nil
      tcmalloc       = value['tcmalloc']      ? value['tcmalloc']      : nil
      storageEngine  = value['storageEngine'] ? value['storageEngine'] : nil
      metrics        = value['metrics']       ? value['metrics']       : nil

      data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'uptime', 'uptime'   , @interval, uptime ) )

      if( asserts != nil )
        regular   = asserts['regular']   ? asserts['regular'] : nil
        warning   = asserts['warning']   ? asserts['warning'] : nil
        message   = asserts['msg']       ? asserts['msg'] : nil
        user      = asserts['user']      ? asserts['user'] : nil
        rollovers = asserts['rollovers'] ? asserts['rollovers'] : nil

        data.push( sprintf( format, @Host, @Service, 'asserts', 'regular'   , @interval, regular ) )
        data.push( sprintf( format, @Host, @Service, 'asserts', 'warning'   , @interval, warning ) )
        data.push( sprintf( format, @Host, @Service, 'asserts', 'message'   , @interval, message ) )
        data.push( sprintf( format, @Host, @Service, 'asserts', 'user'      , @interval, user ) )
        data.push( sprintf( format, @Host, @Service, 'asserts', 'rollovers' , @interval, rollovers ) )
      end

      if( connections != nil )
        current        = connections['current']       ? connections['current'] : nil
        available      = connections['available']     ? connections['available'] : nil
        totalCreated   = connections['totalCreated']  ? connections['totalCreated'] : nil

        if( totalCreated )
          totalCreated = totalCreated['$numberLong']  ? totalCreated['$numberLong'] : nil
        end

        data.push( sprintf( format, @Host, @Service, 'connections', 'current'     , @interval, current ) )
        data.push( sprintf( format, @Host, @Service, 'connections', 'available'   , @interval, available ) )
        data.push( sprintf( format, @Host, @Service, 'connections', 'totalCreated', @interval, totalCreated ) )
      end

      if( network != nil )
        bytesIn   = network['bytesIn']      ? network['bytesIn']      : nil
        bytesOut  = network['bytesOut']     ? network['bytesOut']     : nil
        requests  = network['numRequests']  ? network['numRequests']  : nil
        bytesIn   = bytesIn['$numberLong']  ? bytesIn['$numberLong']  : nil
        bytesOut  = bytesOut['$numberLong'] ? bytesOut['$numberLong'] : nil
        requests  = requests['$numberLong'] ? requests['$numberLong'] : nil

        data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-in', @interval, bytesIn ) )
        data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-out', @interval, bytesOut ) )
        data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'total_requests' , @interval, requests ) )
      end

      if( opcounters != nil )
        insert  = opcounters['insert']  ? opcounters['insert']  : nil
        query   = opcounters['query']   ? opcounters['query']   : nil
        update  = opcounters['update']  ? opcounters['update']  : nil
        delete  = opcounters['delete']  ? opcounters['delete']  : nil
        getmore = opcounters['getmore'] ? opcounters['getmore'] : nil
        command = opcounters['command'] ? opcounters['command'] : nil

        data.push( sprintf( format, @Host, @Service, 'opcounters', 'insert'  , @interval, insert ) )
        data.push( sprintf( format, @Host, @Service, 'opcounters', 'query'   , @interval, query ) )
        data.push( sprintf( format, @Host, @Service, 'opcounters', 'update'  , @interval, update ) )
        data.push( sprintf( format, @Host, @Service, 'opcounters', 'delete'  , @interval, delete ) )
        data.push( sprintf( format, @Host, @Service, 'opcounters', 'getmore' , @interval, getmore ) )
        data.push( sprintf( format, @Host, @Service, 'opcounters', 'command' , @interval, command ) )
      end

      if( tcmalloc != nil )
        generic = tcmalloc['generic']  ? tcmalloc['generic'] : nil
        malloc  = tcmalloc['tcmalloc'] ? tcmalloc['tcmalloc'] : nil

        heapSize         = generic['heap_size']               ? generic['heap_size'] : nil
        heapUsed         = generic['current_allocated_bytes'] ? generic['current_allocated_bytes'] : nil # Bytes in use by application

        percent   = ( 100 * heapUsed / heapSize )

        pageMapFree      = tcmalloc['pageheap_free_bytes']              ? tcmalloc['pageheap_free_bytes']              : nil  # Bytes in page heap freelist
        centralCacheFree = tcmalloc['central_cache_free_bytes' ]        ? tcmalloc['central_cache_free_bytes' ]        : nil  # Bytes in central cache freelist
        transferCacheFee = tcmalloc['transfer_cache_free_bytes']        ? tcmalloc['transfer_cache_free_bytes']        : nil  # Bytes in transfer cache freelist
        threadCacheSize  = tcmalloc['current_total_thread_cache_bytes'] ? tcmalloc['current_total_thread_cache_bytes'] : nil  # Bytes in thread cache freelists
        threadCacheFree  = tcmalloc['thread_cache_free_bytes']          ? tcmalloc['thread_cache_free_bytes']          : nil  #
#        maxThreadCache   = tcmalloc['max_total_thread_cache_bytes']     ? tcmalloc['max_total_thread_cache_bytes']     : nil  #
#        maxThreadCache   = maxThreadCache['$numberLong']                ? maxThreadCache['$numberLong']                : nil  #

        data.push( sprintf( format, @Host, @Service, 'heap_memory', 'size' , @interval, heapSize ) )
        data.push( sprintf( format, @Host, @Service, 'heap_memory', 'used' , @interval, heapUsed ) )
        data.push( sprintf( format, @Host, @Service, 'heap_memory', 'used_percent', @interval, percent ) )

        data.push( sprintf( format, @Host, @Service, 'cache', 'central_free' , @interval, centralCacheFree ) )
        data.push( sprintf( format, @Host, @Service, 'cache', 'transfer_free', @interval, transferCacheFee ) )
#        data.push( sprintf( format, @Host, @Service, 'cache', 'thread_size'  , @interval, maxThreadCache ) )
        data.push( sprintf( format, @Host, @Service, 'cache', 'thread_used'  , @interval, threadCacheSize ) )
        data.push( sprintf( format, @Host, @Service, 'cache', 'thread_free'  , @interval, threadCacheFree ) )

      end

      if( storageEngine != nil )

        storageEngine  = storageEngine['name'] ? storageEngine['name'] : nil

        if( storageEngine != nil )

          storage = value[storageEngine] ? value[storageEngine] : nil

          if( storage != nil )

            blockManager = storage['block-manager'] ? storage['block-manager']  : nil
            connection   = storage['connection']    ? storage['connection']     : nil

            storageBytesRead           = blockManager['bytes read']         ? blockManager['bytes read']         : nil
            storageBytesWritten        = blockManager['bytes written']      ? blockManager['bytes written']      : nil
            storageBlocksRead          = blockManager['blocks read']        ? blockManager['blocks read']        : nil
            storageBlocksWritten       = blockManager['blocks written']     ? blockManager['blocks written']     : nil

            storageConnectionIORead    = connection['total read I/Os']      ? connection['total read I/Os']      : nil
            storageConnectionIOWrite   = connection['total write I/Os']     ? connection['total write I/Os']     : nil
            storageConnectionFilesOpen = connection['files currently open'] ? connection['files currently open'] : nil

            data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-read', @interval , storageBytesRead ) )
            data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-write', @interval, storageBytesWritten ) )
            data.push( sprintf( format, @Host, @Service, 'blocks', 'read'  , @interval, storageBlocksRead ) )
            data.push( sprintf( format, @Host, @Service, 'blocks', 'write' , @interval, storageBlocksWritten ) )

            data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'io_octets-read', @interval , storageConnectionIORead ) )
            data.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'io_octets-write', @interval, storageConnectionIOWrite ) )

            data.push( sprintf( format, @Host, @Service, 'files', 'open', @interval, storageConnectionFilesOpen ) )
          end
        end
      end

      if( metrics != nil )
        ['authenticate','buildInfo','createIndexes','delete','drop','find','findAndModify','insert','listCollections','mapReduce','renameCollection','update'].each do |m|

          cmd = metrics['commands'][m] ? metrics['commands'][m] : nil
          if( cmd != nil )
            d = cmd['total']['$numberLong'] ? cmd['total']['$numberLong']  : nil
            data.push( sprintf( format, @Host, @Service, 'commands', m , @interval, d ) )
          end
        end
      end

      return data

    end
  end

  def ParseResult_Runtime( data = {} )

    mbean = 'Runtime'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      uptime   = value['Uptime']    ? value['Uptime']    : nil
      start    = value['StartTime'] ? value['StartTime'] : nil

      data.push( sprintf( 'PUTVAL %s/%s-%s-%s/uptime interval=%s N:%s', @Host, @Service, mbean, 'uptime'   , @interval, uptime ) )
      data.push( sprintf( 'PUTVAL %s/%s-%s-%s/gauge interval=%s N:%s' , @Host, @Service, mbean, 'starttime', @interval, start ) )

    else

      format.gsub!( 'PUTVAL'          , 'PUTNOTIF' )
      format.gsub!( 'interval=%s N:%s', "message='N/A'" )

      data.push( sprintf( format, @Host, @Service, mbean, 'uptime' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'starttime' ) )
    end

    return data
  end

  def ParseResult_Memory( data = {} )

    mbean = 'Memory'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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

        data.push( sprintf( format, @Host, @Service, mbean, type, 'init'        , @interval, init ) )
        data.push( sprintf( format, @Host, @Service, mbean, type, 'max'         , @interval, max ) )
        data.push( sprintf( format, @Host, @Service, mbean, type, 'used'        , @interval, used ) )
        data.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent', @interval, percent ) )
        data.push( sprintf( format, @Host, @Service, mbean, type, 'committed'   , @interval, committed ) )
      end
    else

      format.gsub!( 'PUTVAL'          , 'PUTNOTIF' )
      format.gsub!( 'interval=%s N:%s', "message='N/A'" )

      data.push( sprintf( format, @Host, @Service, mbean, type, 'init' ) )
      data.push( sprintf( format, @Host, @Service, mbean, type, 'max' ) )
      data.push( sprintf( format, @Host, @Service, mbean, type, 'used' ) )
      data.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent' ) )
      data.push( sprintf( format, @Host, @Service, mbean, type, 'committed') )
    end

    return data

  end


  def ParseResult_Threading( data = {} )

    mbean = 'Threading'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : nil
      count  = value['ThreadCount']      ? value['ThreadCount']      : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'threading', 'peak' , @interval, peak ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'threading', 'count', @interval, count ) )

    else

    end

    return data

  end


  def ParseResult_ThreadPool( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_ClassLoading( data = {} )

    mbean = 'ClassLoading'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      loaded      = value['LoadedClassCount']      ? value['LoadedClassCount']      : nil
      totalLoaded = value['TotalLoadedClassCount'] ? value['TotalLoadedClassCount'] : nil
      unloaded    = value['UnloadedClassCount']    ? value['UnloadedClassCount']    : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'loaded'  , @interval, loaded ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'total'   , @interval, totalLoaded ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'unloaded', @interval, unloaded ) )

    else


    end

    return data

  end


  def ParseResult_GCParNew( data = {} )

    mbean = 'GCParNew'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

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

              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
            end
         end
        end
      end
    end

    return data

  end


  def ParseResult_GCConcurrentMarkSweep( data = {} )

    mbean = 'GCConcurrentMarkSweep';
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

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

              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
              data.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
            end
         end
        end
      end
    end

    return data

  end


  def ParseResult_Server( data = {} )

    mbean = 'Server'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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

      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_hits'     , @interval, cacheHits ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_evicts'   , @interval, cacheEvicts ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_entries'  , @interval, cacheEntries ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_interval' , @interval, cacheInterval ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_size'     , @interval, cacheSize ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'sequence_number', @interval, reqSeqNumber ) )

    else


    end

    return data

  end


  def ParseResult_Feeder( data = {} )

    mbean = 'Feeder'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )
      pendingEvents           = value['PendingEvents']              ? value['PendingEvents']              : nil
      indexDocuments          = value['IndexDocuments']             ? value['IndexDocuments']             : nil
      indexContentDocuments   = value['IndexContentDocuments']      ? value['IndexContentDocuments']      : nil
      currentPendingDocuments = value['CurrentPendingDocuments']    ? value['CurrentPendingDocuments']    : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'pending_events'            , @interval, pendingEvents ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_documents'           , @interval, indexDocuments ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )
    end

    return data

  end


  def ParseResult_CacheClasses( data = {} )

    mbean = 'CacheClasses'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )
      capacity  = value['Capacity']    ? value['Capacity']    : nil
      evaluated = value['Evaluated']   ? value['Evaluated']   : nil
      evicted   = value['Evicted']     ? value['Evicted']     : nil
      inserted  = value['Inserted']    ? value['Inserted']    : nil
      removed   = value['Removed']     ? value['Removed']     : nil
      level     = value['Level']       ? value['Level']       : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'level'     , @interval, level ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'capacity'  , @interval, capacity ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'evaluated' , @interval, evaluated ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'evicted'   , @interval, evicted ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'inserted'  , @interval, inserted ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'content_beans', 'removed'   , @interval, removed ) )
    end

    return data

  end


  # Check for the CAEFeeder
  def ParseResult_ProactiveEngine( data = {} )

    # TODO check first

#    {
#      "Health": {
#        "status": 200,
#        "timestamp": 1471618816,
#        "request": {
#          "mbean": "com.coremedia:application=caefeeder,type=Health",
#          "type": "read",
#          "target": {
#            "url": "service:jmx:rmi:///jndi/rmi://monitoring-16-01:40899/jmxrmi"
#          }
#        },
#        "value": {
#          "MaximumQueueExceededDuration": 900000,
#          "Healthy": true,
#          "MaximumHeartBeat": 300000,
#          "MaximumQueueUtilization": 0.95
#        }
#      }
#    },
    # --------------------------------------------------------------------------------------------
    mbean = 'ProactiveEngine'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      maxEntries     = value['KeysCount']     ? value['KeysCount']     : 0  # max feeder entries
      currentEntries = value['ValuesCount']   ? value['ValuesCount']   : 0  # current feeder entries
      diffEntries    = ( maxEntries - currentEntries ).to_i

      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max'      , @interval, maxEntries ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current'  , @interval, currentEntries ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff'     , @interval, diffEntries ) )

    else

      format.gsub!( 'PUTVAL'          , 'PUTNOTIF' )
      format.gsub!( 'interval=%s N:%s', "message='N/A'" )

      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff' ) )
    end

    return data
  end


  def ParseResult_CapConnection( data = {} )

    mbean = 'CapConnection'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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

      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'size'        , @interval, blobCacheSize ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used'        , @interval, blobCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'fault'       , @interval, blobCacheFaults ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used_percent', @interval, blobCachePercent ) )

      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'size'        , @interval, heapCacheSize ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used'        , @interval, heapCacheLevel ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'fault'       , @interval, heapCacheFaults ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used_percent', @interval, heapCachePercent ) )

      data.push( sprintf( format, @Host, @Service, mbean, 'su_sessions', 'sessions'   , @interval, suSessions ) )

    else

      format.gsub!( 'PUTVAL'          , 'PUTNOTIF' )
      format.gsub!( 'interval=%s N:%s', "message='N/A'" )

      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'size' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'fault' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used_percent' ) )

      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'size' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'fault' ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used_percent' ) )

      data.push( sprintf( format, @Host, @Service, mbean, 'su_sessions', 'sessions' ) )
    end

    return data

  end


  def ParseResult_SolrReplication( data = {} )

    mbean = 'Replication'

    value      = data['value']            ? data['value']            : nil
    solrMbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( solrMbean )

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

      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index_size', @interval, indexSize.to_s ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index'     , @interval, indexVersion ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'    , @interval, errors ) )

    end

    return data

  end


  def ParseResult_SolrQueryResultCache( data = {} )

    mbean = 'QueryResultCache'

    value      = data['value']            ? data['value']            : nil
    solrMbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( solrMbean )

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

      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'warmupTime'  , @interval, warmupTime ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'lookups'     , @interval, lookups ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'evictions'   , @interval, evictions ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'inserts'     , @interval, inserts ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hits'        , @interval, hits ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'size'        , @interval, size ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hitratio'    , @interval, hitratio ) )

    end

    return data

  end

  def ParseResult_SolrDocumentCache( data = {} )

    mbean = 'DocumentCache'

    value      = data['value']            ? data['value']            : nil
    solrMbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( solrMbean )

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

      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'warmupTime'  , @interval, warmupTime ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'lookups'     , @interval, lookups ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'evictions'   , @interval, evictions ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'inserts'     , @interval, inserts ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hits'        , @interval, hits ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'size'        , @interval, size ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hitratio'    , @interval, hitratio ) )

    end

    return data

  end

  def ParseResult_SolrSelect( data = {} )

    mbean = 'Select'

    value      = data['value']            ? data['value']            : nil
    solrMbean  = data['request']['mbean'] ? data['request']['mbean'] : nil

    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    solrCore = self.solrCore( solrMbean )

    if( value != nil )

      avgRequestsPerSecond   = value['avgRequestsPerSecond']   ? value['avgRequestsPerSecond'] : nil
      avgTimePerRequest      = value['avgTimePerRequest']      ? value['avgTimePerRequest']    : nil
      medianRequestTime      = value['medianRequestTime']      ? value['medianRequestTime']    : nil
      requests               = value['requests']               ? value['requests']             : nil
      timeouts               = value['timeouts']               ? value['timeouts']             : nil
      errors                 = value['errors']                 ? value['errors']               : nil

      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgRequestsPerSecond'  , @interval, avgRequestsPerSecond ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgTimePerRequest'     , @interval, avgTimePerRequest ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'medianRequestTime'     , @interval, medianRequestTime ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'requests'              , @interval, requests ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'timeouts'              , @interval, timeouts ) )
      data.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'                , @interval, errors ) )

    end

  end

  def ParseResult_ConnectionPool( data = {} )

    mbean = 'ConnectionPool'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      open   = value['OpenConnections']  ? value['OpenConnections']  : nil
      max    = value['MaxConnections']   ? value['MaxConnections']   : nil
      idle   = value['IdleConnections']  ? value['IdleConnections']  : nil
      busy   = value['BusyConnections']  ? value['BusyConnections']  : nil
      min    = value['MinConnections']   ? value['MinConnections']   : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'open', @interval, open ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'max' , @interval, max ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'idle', @interval, idle ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'busy', @interval, busy ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'min' , @interval, min ) )

    else


    end

    return data

  end


  def ParseResult_QueryPool( data = {} )

    mbean = 'QueryPool'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      executorsRunning = value['RunningExecutors'] ? value['RunningExecutors'] : nil
      executorsIdle    = value['IdleExecutors']    ? value['IdleExecutors']    : nil
      queriesMax       = value['MaxQueries']       ? value['MaxQueries']       : nil
      queriesWaiting   = value['WaitingQueries']   ? value['WaitingQueries']   : nil


      data.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_running', @interval, executorsRunning ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_idle'   , @interval, executorsIdle ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_max'      , @interval, queriesMax ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_waiting'  , @interval, queriesWaiting ) )

    else


    end

    return data

  end


  def ParseResult_StatisticsBlobStoreMethods( data = {} )

    # was für komische Werte kommen da aus JMX raus?
    # müssen wir klären

  end


  def ParseResult_StatisticsJobResult( data = {} )

    mbean = 'StatisticsJobResult'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      failed        = value['Failed']        ? value['Failed']        : nil
      successful    = value['Successful']    ? value['Successful']    : nil
      unrecoverable = value['Unrecoverable'] ? value['Unrecoverable'] : nil

      data.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'failed'       , @interval, failed ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'successful'   , @interval, successful ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'unrecoverable', @interval, unrecoverable ) )

    else

    end

    return data

  end


  def ParseResult_StatisticsResourceCache( data = {} )

    mbean = 'StatisticsResourceCache'
    value  = data['value'] ? data['value'] : nil
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    data   = []

    if( value != nil )

      size     = value['CacheSize']     ? value['CacheSize']     : nil
      removed  = value['CacheRemoved']  ? value['CacheRemoved']  : nil
      faults   = value['CacheFaults']   ? value['CacheFaults']   : nil
      misses   = value['CacheMisses']   ? value['CacheMisses']   : nil
      hits     = value['CacheHits']     ? value['CacheHits']     : nil


      data.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'size'   , @interval, size ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'removed', @interval, removed ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'faults' , @interval, faults ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'misses' , @interval, misses ) )
      data.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'hits'   , @interval, hits ) )

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
                when 'mongodb'
                  graphiteOutput.push( self.ParseResult_mongoDB( v ) )
                when 'Runtime'
                  graphiteOutput.push( self.ParseResult_Runtime( v ) )
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
                when /^Solr.*DocumentCache/
                  graphiteOutput.push( self.ParseResult_SolrDocumentCache( v ) )
                when /^Solr.*Select/
                  graphiteOutput.push( self.ParseResult_SolrSelect( v ) )
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
