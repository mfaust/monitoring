#!/usr/bin/ruby
#
# 14.09.2016 - Bodo Schulz
#
#
# v1.3.1

# -----------------------------------------------------------------------------

require 'time'
require 'date'
require 'time_difference'
require 'logger'
require 'json'
require 'filesize'
require 'fileutils'

require_relative 'tools'

# -----------------------------------------------------------------------------

class Time
  def add_minutes(m)
    self + (60 * m)
  end
end

class CollecdPlugin

#  attr_reader :status, :message, :services

  def initialize( settings = {} )

    @logDirectory   = settings['log_dir']      ? settings['log_dir']      : '/tmp'
    @cacheDirectory = settings['cache_dir']    ? settings['cache_dir']    : '/var/tmp/monitoring'
    @memcacheHost   = settings['memcacheHost'] ? settings['memcacheHost'] : nil
    @memcachePort   = settings['memcachePort'] ? settings['memcachePort'] : nil
    @interval       = settings['interval']     ? settings['interval']     : 15

    logFile = sprintf( '%s/collectd.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    if( File.exists?( logFile ) )
      FileUtils.chmod( 0666, logFile )
      FileUtils.chown( 'nobody', 'nobody', logFile )
    end

    if( @memcacheHost != nil && @memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @supportMemcache = true

    end


    version              = '1.3.1'
    date                 = '2016-10-04'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CoreMedia - CollectdPlugin' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( "  cache directory located at #{@cacheDirectory}" )
    @log.info( "  configured interval #{@interval}" )

    if( @supportMemcache == true )
      @log.info( "  Memcache Support enabled" )
      @log.info( "  Memcache Server #{@memcacheHost}:#{@memcachePort}" )
    end

    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

  end


  def output( data = [] )

    data.each do |d|
      if( d )
        puts d
      end
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
    return sprintf( 'core_%s', parts['core'].to_s.strip.tr( '. ', '' ).downcase )

  end


  def beanName( mbean )

      regex = /
        ^                     # Starting at the front of the string
        (.*)                  #
        name=                 #
        (?<name>.+[a-zA-Z])   #
        (.*),                 #
        type=                 #
        (?<type>.+[a-zA-Z])   #
        $
      /x

      parts           = mbean.match( regex )
      mbeanName       = parts['name'].to_s
      mbeanType       = parts['type'].to_s

    return mbeanName
  end


  def beanTimeout?( timestamp )

    result = false
    quorum = 1 # in minutes

    if( timestamp == nil || timestamp.to_s == 'null' )
      result = true
    else
      n = Time.now()
      t = Time.at( timestamp )
      t = t.add_minutes( quorum ) + 10

      difference = TimeDifference.between( t, n ).in_each_component
      difference = difference[:minutes].ceil

      if( difference > quorum + 1 )

        @log.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
        @log.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
        @log.debug( sprintf( ' difference: %d', difference ) )

        result = true
      end
    end

    return result

  end


  def checkBean‎Consistency( mbean, data = {} )

    result = true

    status    = data['status']    ? data['status']    : 505
    timestamp = data['timestamp'] ? data['timestamp'] : 0

    if( self.beanTimeout?( timestamp ) )

      @log.error( sprintf( ' -> Host: \'%s\' - Service: \'%s\' - mbean: \'%s\' - status: \'timeout\'', @Host, @Service, mbean ) )
      result = false
    end

    if( status.to_i != 200 )

      @log.error( sprintf( ' -> Host: \'%s\' - Service: \'%s\' - mbean: \'%s\' - status: \'%d\'', @Host, @Service, mbean, status ) )
      result = false
    end

    return result

  end


  def ParseResult_mongoDB( value = {} )

    format = 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s'
    result = []

    if( value != nil )

      uptime         = value['uptime']

      asserts        = value['asserts']       ? value['asserts']       : nil
      connections    = value['connections']   ? value['connections']   : nil
      network        = value['network']       ? value['network']       : nil
      opcounters     = value['opcounters']    ? value['opcounters']    : nil
      tcmalloc       = value['tcmalloc']      ? value['tcmalloc']      : nil
      storageEngine  = value['storageEngine'] ? value['storageEngine'] : nil
      metrics        = value['metrics']       ? value['metrics']       : nil
      mem            = value['mem']           ? value['mem']           : nil
      extraInfo      = value['extra_info']    ? value['extra_info']    : nil
      wiredTiger     = value['wiredTiger']    ? value['wiredTiger']    : nil
      globalLock     = value['globalLock']    ? value['globalLock']    : nil


      result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'uptime', 'uptime'   , @interval, uptime ) )

      if( asserts != nil )
        regular   = asserts['regular']   ? asserts['regular'] : nil
        warning   = asserts['warning']   ? asserts['warning'] : nil
        message   = asserts['msg']       ? asserts['msg'] : nil
        user      = asserts['user']      ? asserts['user'] : nil
        rollovers = asserts['rollovers'] ? asserts['rollovers'] : nil

        result.push( sprintf( format, @Host, @Service, 'asserts', 'regular'   , @interval, regular ) )
        result.push( sprintf( format, @Host, @Service, 'asserts', 'warning'   , @interval, warning ) )
        result.push( sprintf( format, @Host, @Service, 'asserts', 'message'   , @interval, message ) )
        result.push( sprintf( format, @Host, @Service, 'asserts', 'user'      , @interval, user ) )
        result.push( sprintf( format, @Host, @Service, 'asserts', 'rollovers' , @interval, rollovers ) )
      end

      if( connections != nil )
        current        = connections['current']       ? connections['current'] : nil
        available      = connections['available']     ? connections['available'] : nil
        totalCreated   = connections['totalCreated']  ? connections['totalCreated'] : nil

        if( totalCreated )
          totalCreated = totalCreated['$numberLong']  ? totalCreated['$numberLong'] : nil
        end

        result.push( sprintf( format, @Host, @Service, 'connections', 'current'     , @interval, current ) )
        result.push( sprintf( format, @Host, @Service, 'connections', 'available'   , @interval, available ) )
        result.push( sprintf( format, @Host, @Service, 'connections', 'totalCreated', @interval, totalCreated ) )
      end

      if( network != nil )
        bytesIn   = network['bytesIn']      ? network['bytesIn']      : nil
        bytesOut  = network['bytesOut']     ? network['bytesOut']     : nil
        requests  = network['numRequests']  ? network['numRequests']  : nil
        bytesIn   = bytesIn['$numberLong']  ? bytesIn['$numberLong']  : nil
        bytesOut  = bytesOut['$numberLong'] ? bytesOut['$numberLong'] : nil
        requests  = requests['$numberLong'] ? requests['$numberLong'] : nil

        result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-in', @interval, bytesIn ) )
        result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'bytes-out', @interval, bytesOut ) )
        result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'network', 'total_requests' , @interval, requests ) )
      end

      if( opcounters != nil )
        insert  = opcounters['insert']  ? opcounters['insert']  : nil
        query   = opcounters['query']   ? opcounters['query']   : nil
        update  = opcounters['update']  ? opcounters['update']  : nil
        delete  = opcounters['delete']  ? opcounters['delete']  : nil
        getmore = opcounters['getmore'] ? opcounters['getmore'] : nil
        command = opcounters['command'] ? opcounters['command'] : nil

        result.push( sprintf( format, @Host, @Service, 'opcounters', 'insert'  , @interval, insert ) )
        result.push( sprintf( format, @Host, @Service, 'opcounters', 'query'   , @interval, query ) )
        result.push( sprintf( format, @Host, @Service, 'opcounters', 'update'  , @interval, update ) )
        result.push( sprintf( format, @Host, @Service, 'opcounters', 'delete'  , @interval, delete ) )
        result.push( sprintf( format, @Host, @Service, 'opcounters', 'getmore' , @interval, getmore ) )
        result.push( sprintf( format, @Host, @Service, 'opcounters', 'command' , @interval, command ) )
      end

      if( tcmalloc != nil )
        generic = tcmalloc['generic']  ? tcmalloc['generic'] : nil
        malloc  = tcmalloc['tcmalloc'] ? tcmalloc['tcmalloc'] : nil

        heapSize         = generic['heap_size']               ? generic['heap_size'] : nil
        heapUsed         = generic['current_allocated_bytes'] ? generic['current_allocated_bytes'] : nil # Bytes in use by application

        percent   = ( 100 * heapUsed / heapSize )

        # pageMapFree      = tcmalloc['pageheap_free_bytes']              ? tcmalloc['pageheap_free_bytes']              : nil  # Bytes in page heap freelist
        # centralCacheFree = tcmalloc['central_cache_free_bytes' ]        ? tcmalloc['central_cache_free_bytes' ]        : nil  # Bytes in central cache freelist
        # transferCacheFee = tcmalloc['transfer_cache_free_bytes']        ? tcmalloc['transfer_cache_free_bytes']        : nil  # Bytes in transfer cache freelist
        # threadCacheSize  = tcmalloc['current_total_thread_cache_bytes'] ? tcmalloc['current_total_thread_cache_bytes'] : nil  # Bytes in thread cache freelists
        # threadCacheFree  = tcmalloc['thread_cache_free_bytes']          ? tcmalloc['thread_cache_free_bytes']          : nil  #
        # maxThreadCache   = tcmalloc['max_total_thread_cache_bytes']     ? tcmalloc['max_total_thread_cache_bytes']     : nil  #
        # maxThreadCache   = maxThreadCache['$numberLong']                ? maxThreadCache['$numberLong']                : nil  #

        result.push( sprintf( format, @Host, @Service, 'heap_memory', 'size' , @interval, heapSize ) )
        result.push( sprintf( format, @Host, @Service, 'heap_memory', 'used' , @interval, heapUsed ) )
        result.push( sprintf( format, @Host, @Service, 'heap_memory', 'used_percent', @interval, percent ) )
#
        # result.push( sprintf( format, @Host, @Service, 'cache', 'central_free' , @interval, centralCacheFree ) )
        # result.push( sprintf( format, @Host, @Service, 'cache', 'transfer_free', @interval, transferCacheFee ) )
        # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_size'  , @interval, maxThreadCache ) )
        # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_used'  , @interval, threadCacheSize ) )
        # result.push( sprintf( format, @Host, @Service, 'cache', 'thread_free'  , @interval, threadCacheFree ) )

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

            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-read', @interval , storageBytesRead ) )
            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'bytes', 'bytes-write', @interval, storageBytesWritten ) )
            result.push( sprintf( format, @Host, @Service, 'blocks', 'read'  , @interval, storageBlocksRead ) )
            result.push( sprintf( format, @Host, @Service, 'blocks', 'write' , @interval, storageBlocksWritten ) )

            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'count-read', @interval , storageConnectionIORead ) )
            result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s', @Host, @Service, 'io', 'count-write', @interval, storageConnectionIOWrite ) )

            result.push( sprintf( format, @Host, @Service, 'files', 'open', @interval, storageConnectionFilesOpen ) )
          end
        end
      end

      if( metrics != nil )

        commands = metrics['commands'] ? metrics['commands'] : nil

        if( commands != nil )

          ['authenticate','buildInfo','createIndexes','delete','drop','find','findAndModify','insert','listCollections','mapReduce','renameCollection','update'].each do |m|

            cmd = commands[m] ? commands[m] : nil

            if( cmd != nil )
              d = cmd['total']['$numberLong'] ? cmd['total']['$numberLong']  : nil

              result.push( sprintf( format, @Host, @Service, 'commands', m , @interval, d ) )
            end
          end


          currentOp = commands['currentOp'] ? commands['currentOp'] : nil

          if (currentOp != nil)

            total  = currentOp['total']['$numberLong']  ? currentOp['total']['$numberLong']  : nil
            failed = currentOp['failed']['$numberLong'] ? currentOp['failed']['$numberLong'] : nil

            result.push( sprintf( format, @Host, @Service, 'currentOp', 'total',  @interval, total ) )
            result.push( sprintf( format, @Host, @Service, 'currentOp', 'failed', @interval, failed ) )
          end

        end

        cursor = metrics['cursor'] ? metrics['cursor'] : nil
        if (cursor != nil)
          cursorOpen     = cursor['open']     ? cursor['open']     : nil
          cursorTimedOut = cursor['timedOut'] ? cursor['timedOut'] : nil

          if( cursorOpen != nil && cursorTimedOut != nil )

            openNoTimeout = cursorOpen['noTimeout']['$numberLong'] ? cursorOpen['noTimeout']['$numberLong'] : nil
            openTotal     = cursorOpen['total']['$numberLong']     ? cursorOpen['total']['$numberLong']     : nil
            timedOut      = cursorTimedOut['$numberLong']          ? cursorTimedOut['$numberLong']          : nil

            result.push( sprintf( format, @Host, @Service, 'cursor', 'open-total',      @interval, openTotal ) )
            result.push( sprintf( format, @Host, @Service, 'cursor', 'open-no-timeout', @interval, openNoTimeout ) )
            result.push( sprintf( format, @Host, @Service, 'cursor', 'timed-out',       @interval, timedOut ) )
          end

        end

      end

      if( mem != nil )

        virtual        = mem['virtual']       ? mem['virtual']  : nil
        resident       = mem['resident']      ? mem['resident'] : nil

        result.push( sprintf( format, @Host, @Service, 'mem', 'virtual'    , @interval, virtual ) )
        result.push( sprintf( format, @Host, @Service, 'mem', 'resident'   , @interval, resident ) )
      end

      if( extraInfo != nil )

        pageFaults        = extraInfo['page_faults']       ? extraInfo['page_faults']  : nil

        result.push( sprintf( format, @Host, @Service, 'extraInfo', 'pageFaults' , @interval, pageFaults ) )
      end

      if( wiredTiger != nil )

        wiredTigerCache = wiredTiger['cache'] ? wiredTiger['cache'] : nil

        if( wiredTigerCache != nil )
          bytes         = wiredTigerCache['bytes currently in the cache']      ? wiredTigerCache['bytes currently in the cache']      : nil
          maximum       = wiredTigerCache['maximum bytes configured']          ? wiredTigerCache['maximum bytes configured']          : nil
          tracked       = wiredTigerCache['tracked dirty bytes in the cache']  ? wiredTigerCache['tracked dirty bytes in the cache']  : nil
          unmodified    = wiredTigerCache['unmodified pages evicted']          ? wiredTigerCache['unmodified pages evicted']          : nil
          modified      = wiredTigerCache['modified pages evicted']            ? wiredTigerCache['modified pages evicted']            : nil

          result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'bytes'      , @interval, bytes ) )
          result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'maximum'    , @interval, maximum ) )
          result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'tracked'    , @interval, tracked ) )
          result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'unmodified' , @interval, unmodified ) )
          result.push( sprintf( format, @Host, @Service, 'wiredTigerCache', 'modified'   , @interval, modified ) )
        end


        concurrentTransactions = wiredTiger['concurrentTransactions'] ? wiredTiger['concurrentTransactions'] : nil

        if (concurrentTransactions)
          read        = concurrentTransactions['read']       ? concurrentTransactions['read']     : nil
          write       = concurrentTransactions['write']      ? concurrentTransactions['write']    : nil

          if (read != nil && write != nil)

            readOut          = read['out']         ? read['out']       : nil
            readAvailable    = read['available']   ? read['available'] : nil

            writeOut         = write['out']        ? write['out']       : nil
            writeAvailable   = write['available']  ? write['available'] : nil

            result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'readOut'          , @interval, readOut ) )
            result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'readAvailable'    , @interval, readAvailable ) )
            result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'writeOut'         , @interval, writeOut ) )
            result.push( sprintf( format, @Host, @Service, 'wiredTigerConcTrans', 'writeAvailable'   , @interval, writeAvailable ) )
          end

        end
      end

      if( globalLock != nil )

        currentQueue = globalLock['currentQueue'] ? globalLock['currentQueue'] : nil

        if (currentQueue)
          readers       = currentQueue['readers']    ? currentQueue['readers']  : nil
          writers       = currentQueue['writers']    ? currentQueue['writers']  : nil
          total         = currentQueue['total']      ? currentQueue['total']    : nil

          result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'readers'    , @interval, readers ) )
          result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'writers'    , @interval, writers ) )
          result.push( sprintf( format, @Host, @Service, 'globalLockCurrentQueue', 'total'      , @interval, total ) )

        end

        activeClients = globalLock['activeClients'] ? globalLock['activeClients'] : nil

        if (currentQueue)
          readers     = activeClients['readers']    ? activeClients['readers']  : nil
          writers     = activeClients['writers']    ? activeClients['writers']  : nil
          total       = activeClients['total']      ? activeClients['total']    : nil

          result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'readers'    , @interval, readers ) )
          result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'writers'    , @interval, writers ) )
          result.push( sprintf( format, @Host, @Service, 'globalLockActiveClients', 'total'      , @interval, total ) )

        end
      end

      return result

    end
  end


  def ParseResult_mySQL( value = {} )

    format = 'PUTVAL %s/%s-%s/%s-%s interval=%s N:%s'
    result = []

    if( value != nil )

      # READ THIS : http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html

      bytesReceived                   = value['Bytes_received']             ? value['Bytes_received']             : nil
      bytesSent                       = value['Bytes_sent']                 ? value['Bytes_sent']                 : nil
      connections                     = value['Connections']                ? value['Connections']                : nil
      createdTmpDiskTables            = value['Created_tmp_disk_tables']    ? value['Created_tmp_disk_tables']    : nil
      createdTmpFiles                 = value['Created_tmp_files']          ? value['Created_tmp_files']          : nil
      createdTmpTables                = value['Created_tmp_tables']         ? value['Created_tmp_tables']         : nil
      handlerCommit                   = value['Handler_commit']             ? value['Handler_commit']             : nil    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Handler_commit
      handlerDelete                   = value['Handler_delete']             ? value['Handler_delete']             : nil
      handlerDiscover                 = value['Handler_discover']           ? value['Handler_discover']           : nil
      handlerPrepare                  = value['Handler_prepare']            ? value['Handler_prepare']            : nil
      handlerReadFirst                = value['Handler_read_first']         ? value['Handler_read_first']         : nil
      handlerReadKey                  = value['Handler_read_key']           ? value['Handler_read_key']           : nil
      handlerReadLast                 = value['Handler_read_last']          ? value['Handler_read_last']          : nil
      handlerReadNext                 = value['Handler_read_next']          ? value['Handler_read_next']          : nil
      handlerReadPrev                 = value['Handler_read_prev']          ? value['Handler_read_prev']          : nil
      handlerReadRnd                  = value['Handler_read_rnd']           ? value['Handler_read_rnd']           : nil
      handlerReadRndNext              = value['Handler_read_rnd_next']      ? value['Handler_read_rnd_next']      : nil
      handlerRollback                 = value['Handler_rollback']           ? value['Handler_rollback']           : nil
      handlerSavepoint                = value['Handler_savepoint']          ? value['Handler_savepoint']          : nil
      handlerSavepointRollback        = value['Handler_savepoint_rollback'] ? value['Handler_savepoint_rollback'] : nil
      handlerUpdate                   = value['Handler_update']             ? value['Handler_update']             : nil
      handlerWrite                    = value['Handler_write']              ? value['Handler_write']              : nil
      qcacheFreeBlocks                = value['Qcache_free_blocks']         ? value['Qcache_free_blocks']         : nil    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Qcache_free_blocks
      qcacheFreeMemory                = value['Qcache_free_memory']         ? value['Qcache_free_memory']         : nil
      qcacheHits                      = value['Qcache_hits']                ? value['Qcache_hits']                : nil
      qcacheInserts                   = value['Qcache_inserts']             ? value['Qcache_inserts']             : nil
      qcacheLowmemPrunes              = value['Qcache_lowmem_prunes']       ? value['Qcache_lowmem_prunes']       : nil
      qcacheNotCached                 = value['Qcache_not_cached']          ? value['Qcache_not_cached']          : nil
      qcacheQueriesInCache            = value['Qcache_queries_in_cache']    ? value['Qcache_queries_in_cache']    : nil
      qcacheTotalBlocks               = value['Qcache_total_blocks']        ? value['Qcache_total_blocks']        : nil
      questions                       = value['Questions']                  ? value['Questions']                  : nil    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Questions
      queries                         = value['Queries']                    ? value['Queries']                    : nil
      threadsCached                   = value['Threads_cached']             ? value['Threads_cached']             : nil
      threadsConnected                = value['Threads_connected']          ? value['Threads_connected']          : nil
      threadsCreated                  = value['Threads_created']            ? value['Threads_created']            : nil
      threadsRunning                  = value['Threads_running']            ? value['Threads_running']            : nil
      uptime                          = value['Uptime']                     ? value['Uptime']                     : nil

      innodbBufferPoolPagesData       = value['Innodb_buffer_pool_pages_data']         ? value['Innodb_buffer_pool_pages_data']         : nil
      innodbBufferPoolPagesDirty      = value['Innodb_buffer_pool_pages_dirty']        ? value['Innodb_buffer_pool_pages_dirty']        : nil
      innodbBufferPoolPagesFlushed    = value['Innodb_buffer_pool_pages_flushed']      ? value['Innodb_buffer_pool_pages_flushed']      : nil
      innodbBufferPoolPagesFree       = value['Innodb_buffer_pool_pages_free']         ? value['Innodb_buffer_pool_pages_free']         : nil
      innodbBufferPoolPagesMisc       = value['Innodb_buffer_pool_pages_misc']         ? value['Innodb_buffer_pool_pages_misc']         : nil
      innodbBufferPoolPagesTotal      = value['Innodb_buffer_pool_pages_total']        ? value['Innodb_buffer_pool_pages_total']        : nil
      innodbBufferPoolBytesData       = value['Innodb_buffer_pool_bytes_data']         ? value['Innodb_buffer_pool_bytes_data']         : nil
      innodbBufferPoolBytesDirty      = value['Innodb_buffer_pool_bytes_dirty']        ? value['Innodb_buffer_pool_bytes_dirty']        : nil
      innodbBufferPoolReadAheadRnd    = value['Innodb_buffer_pool_read_ahead_rnd']     ? value['Innodb_buffer_pool_read_ahead_rnd']     : nil
      innodbBufferPoolReadAhead       = value['Innodb_buffer_pool_read_ahead']         ? value['Innodb_buffer_pool_read_ahead']         : nil
      innodbBufferPoolReadAheadEviced = value['Innodb_buffer_pool_read_ahead_evicted'] ? value['Innodb_buffer_pool_read_ahead_evicted'] : nil
      innodbBufferPoolReadRequests    = value['Innodb_buffer_pool_read_requests']      ? value['Innodb_buffer_pool_read_requests']      : nil
      innodbBufferPoolReads           = value['Innodb_buffer_pool_reads']              ? value['Innodb_buffer_pool_reads']              : nil
      innodbBufferPoolWaitFree        = value['Innodb_buffer_pool_wait_free']          ? value['Innodb_buffer_pool_wait_free']          : nil
      innodbBufferPoolWriteRequests   = value['Innodb_buffer_pool_write_requests']     ? value['Innodb_buffer_pool_write_requests']     : nil
      innodbPageSize                  = value['Innodb_page_size']                      ? value['Innodb_page_size']                      : nil
      innodbPagesCreated              = value['Innodb_pages_created']                  ? value['Innodb_pages_created']                  : nil
      innodbPagesRead                 = value['Innodb_pages_read']                     ? value['Innodb_pages_read']                     : nil
      innodbPagesWritten              = value['Innodb_pages_written']                  ? value['Innodb_pages_written']                  : nil
      innodbRowsDeleted               = value['Innodb_rows_deleted']                   ? value['Innodb_rows_deleted']                   : nil
      innodbRowsInserted              = value['Innodb_rows_inserted']                  ? value['Innodb_rows_inserted']                  : nil
      innodbRowsRead                  = value['Innodb_rows_read']                      ? value['Innodb_rows_read']                      : nil
      innodbRowsUpdated               = value['Innodb_rows_updated']                   ? value['Innodb_rows_updated']                   : nil

      result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s' , @Host, @Service, 'uptime' , 'uptime'   , @interval, uptime ) )

      result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s' , @Host, @Service, 'network', 'bytes-in' , @interval, bytesReceived ) )
      result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s' , @Host, @Service, 'network', 'bytes-out', @interval, bytesSent ) )

      result.push( sprintf( 'PUTVAL %s/%s-%s/%s interval=%s N:%s' , @Host, @Service, 'connections', 'count', @interval, connections ) )

      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'free_blocks'     , @interval, qcacheFreeBlocks ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'free_memory'     , @interval, qcacheFreeMemory ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'hits'            , @interval, qcacheHits ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'inserts'         , @interval, qcacheInserts ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'low_mem_prunes'  , @interval, qcacheLowmemPrunes ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'not_cached'      , @interval, qcacheNotCached ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'queries_in_cache', @interval, qcacheQueriesInCache ) )
      result.push( sprintf( format ,  @Host, @Service, 'qcache', 'count', 'total_blocks'    , @interval, qcacheTotalBlocks ) )

      result.push( sprintf( format ,  @Host, @Service, 'threads', 'count', 'cached'         , @interval, threadsCached ) )
      result.push( sprintf( format ,  @Host, @Service, 'threads', 'count', 'connected'      , @interval, threadsConnected ) )
      result.push( sprintf( format ,  @Host, @Service, 'threads', 'count', 'created'        , @interval, threadsCreated ) )
      result.push( sprintf( format ,  @Host, @Service, 'threads', 'count', 'running'        , @interval, threadsRunning ) )


      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_data'         , @interval, innodbBufferPoolPagesData ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_dirty'        , @interval, innodbBufferPoolPagesDirty ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_flushed'      , @interval, innodbBufferPoolPagesFlushed ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_free'         , @interval, innodbBufferPoolPagesFree ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_misc'         , @interval, innodbBufferPoolPagesMisc ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'pages_total'        , @interval, innodbBufferPoolPagesTotal ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'bytes_data'         , @interval, innodbBufferPoolBytesData ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'bytes_dirty'        , @interval, innodbBufferPoolBytesDirty ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'read_ahead_rnd'     , @interval, innodbBufferPoolReadAheadRnd ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'read_ahead'         , @interval, innodbBufferPoolReadAhead ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'read_ahead_evicted' , @interval, innodbBufferPoolReadAheadEviced ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_buffer_pool', 'count', 'read_requests'      , @interval, innodbBufferPoolReadRequests ) )

      result.push( sprintf( format ,  @Host, @Service, 'innodb_page' , 'count', 'size'                     , @interval, innodbPageSize ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_pages', 'count', 'created'                  , @interval, innodbPagesCreated ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_pages', 'count', 'read'                     , @interval, innodbPagesRead ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_pages', 'count', 'written'                  , @interval, innodbPagesWritten ) )

      result.push( sprintf( format ,  @Host, @Service, 'innodb_rows', 'count', 'deleted'                   , @interval, innodbRowsDeleted ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_rows', 'count', 'inserted'                  , @interval, innodbRowsInserted ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_rows', 'count', 'read'                      , @interval, innodbRowsRead ) )
      result.push( sprintf( format ,  @Host, @Service, 'innodb_rows', 'count', 'updated'                   , @interval, innodbRowsUpdated ) )

    end

    return result
  end


  def ParseResult_Runtime( data = {} )

    @log.debug( data )

    result    = []
    mbean     = 'Runtime'
    format    = 'PUTVAL %s/%s-%s-%s/%s interval=%s N:%s'
    value     = data['value']     ? data['value']     : nil

    # defaults
    uptime  = 0
    start   = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      uptime   = value['Uptime']    ? value['Uptime']    : nil
      start    = value['StartTime'] ? value['StartTime'] : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'uptime'   , 'uptime', @interval, uptime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'starttime', 'gauge' , @interval, start ) )

    return result
  end


  def ParseResult_OperatingSystem( data = {} )

    result    = []
    mbean     = 'OperatingSystem'
    format    = 'PUTVAL %s/%s-%s-%s/%s interval=%s N:%s'
    value     = data['value']     ? data['value']     : nil

    # defaults
    physicalMemorySizeTotal    = 0
    physicalMemorySizeFree     = 0
    virtualMemorySizeCommitted = 0
    swapSpaceSizeTotal         = 0
    swapSpaceSizeFree          = 0
    systemLoadAverage          = 0
    systemCpuLoad              = 0
    fileDescriptorCountMax     = 0
    fileDescriptorCountOpen    = 0
    vvailableProcessors        = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first
    end

#     result.push( sprintf( format, @Host, @Service, mbean, 'uptime'   , 'uptime', @interval, uptime ) )
#     result.push( sprintf( format, @Host, @Service, mbean, 'starttime', 'gauge' , @interval, start ) )

    return result




#             "value" : {
#                "TotalPhysicalMemorySize" : 10317664256,
#                "SystemLoadAverage" : 9.23,
#                "Arch" : "amd64",
#                "ProcessCpuLoad" : 0.00165745856353591,
#                "MaxFileDescriptorCount" : 4096,
#                "AvailableProcessors" : 2,
#                "OpenFileDescriptorCount" : 82,
#                "FreePhysicalMemorySize" : 138825728,
#                "TotalSwapSpaceSize" : 0,
#                "ObjectName" : {
#                   "objectName" : "java.lang:type=OperatingSystem"
#                },
#                "CommittedVirtualMemorySize" : 3045675008,
#                "Name" : "Linux",
#                "Version" : "3.10.0-327.22.2.el7.x86_64",
#                "ProcessCpuTime" : 277100000000,
#                "SystemCpuLoad" : 0.986195472114854,
#                "FreeSwapSpaceSize" : 0
#             },



  end


  def ParseResult_TomcatManager( data = {} )

    result    = []
    mbean     = 'Manager'
    format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value     = data['value']     ? data['value']     : nil

    # defaults
    processingTime          = 0       # Time spent doing housekeeping and expiration
    duplicates              = 0       # Number of duplicated session ids generated
    maxActiveSessions       = 0       # The maximum number of active Sessions allowed, or -1 for no limit
    sessionMaxAliveTime     = 0       # Longest time an expired session had been alive
    maxInactiveInterval     = 3600    # The default maximum inactive interval for Sessions created by this Manager
    sessionExpireRate       = 0       # Session expiration rate in sessions per minute
    sessionAverageAliveTime = 0       # Average time an expired session had been alive
    rejectedSessions        = 0       # Number of sessions we rejected due to maxActive beeing reached
    processExpiresFrequency = 0       # The frequency of the manager checks (expiration and passivation)
    activeSessions          = 0       # Number of active sessions at this moment
    sessionCreateRate       = 0       # Session creation rate in sessions per minute
    expiredSessions         = 0       # Number of sessions that expired ( doesn't include explicit invalidations )
    sessionCounter          = 0       # Total number of sessions created by this manager
    maxActive               = 0       # Maximum number of active sessions so far

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      duplicates              = value['duplicates']               ? value['duplicates']              : nil
      maxActiveSessions       = value['maxActiveSessions']        ? value['maxActiveSessions']       : nil
      sessionMaxAliveTime     = value['sessionMaxAliveTime']      ? value['sessionMaxAliveTime']     : nil
      processingTime          = value['processingTime']           ? value['processingTime']          : nil
      maxInactiveInterval     = value['maxInactiveInterval']      ? value['maxInactiveInterval']     : nil
      sessionExpireRate       = value['sessionExpireRate']        ? value['sessionExpireRate']       : nil
      sessionAverageAliveTime = value['sessionAverageAliveTime']  ? value['sessionAverageAliveTime'] : nil
      rejectedSessions        = value['rejectedSessions']         ? value['rejectedSessions']        : nil
      processExpiresFrequency = value['processExpiresFrequency']  ? value['processExpiresFrequency'] : nil
      activeSessions          = value['activeSessions']           ? value['activeSessions']          : nil
      sessionCreateRate       = value['sessionCreateRate']        ? value['sessionCreateRate']       : nil
      expiredSessions         = value['expiredSessions']          ? value['expiredSessions']         : nil
      sessionCounter          = value['sessionCounter']           ? value['sessionCounter']          : nil
      maxActive               = value['maxActive']                ? value['maxActive']               : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'processing', 'time'              , @interval, processingTime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'count'             , @interval, sessionCounter ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expired'           , @interval, expiredSessions ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'alive_avg'         , @interval, sessionAverageAliveTime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'rejected'          , @interval, rejectedSessions ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'duplicates'        , @interval, duplicates ) )

    if( maxActiveSessions.to_i != -1 )
      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_active_allowed', @interval, maxActiveSessions ) )
    end
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_alive'         , @interval, sessionMaxAliveTime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expire_rate'       , @interval, sessionExpireRate ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'create_rate'       , @interval, sessionCreateRate ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_active'        , @interval, maxActive ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expire_freq'       , @interval, processExpiresFrequency ) )

    return result
  end


  def ParseResult_DataViewFactory( data = {} )

    result    = []
    mbean     = 'DataViewFactory'
    format    = 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s'
    value     = data['value']     ? data['value']     : nil

    # defaults
    lookups      = 0
    computed     = 0
    cached       = 0
    invalidated  = 0
    evicted      = 0
    activeTime   = 0
    totalTime    = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      lookups      = value['NumberOfDataViewLookups']       ? value['NumberOfDataViewLookups']       : nil
      computed     = value['NumberOfComputedDataViews']     ? value['NumberOfComputedDataViews']     : nil
      cached       = value['NumberOfCachedDataViews']       ? value['NumberOfCachedDataViews']       : nil
      invalidated  = value['NumberOfInvalidatedDataViews']  ? value['NumberOfInvalidatedDataViews']  : nil
      evicted      = value['NumberOfEvictedDataViews']      ? value['NumberOfEvictedDataViews']      : nil
      activeTime   = value['ActiveTimeOfComputedDataViews'] ? value['ActiveTimeOfComputedDataViews'] : nil
      totalTime    = value['TotalTimeOfComputedDataViews']  ? value['TotalTimeOfComputedDataViews']  : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'lookups'     , @interval, lookups ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'computed'    , @interval, computed ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'cached'      , @interval, cached ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'invalidated' , @interval, invalidated ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'evicted'     , @interval, evicted ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'activeTime'  , @interval, activeTime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'totalTime'   , @interval, totalTime ) )

    return result

  end


  def ParseResult_TransformedBlobCacheManager( data = {} )

    result    = []
    mbean     = 'TransformedBlobCacheManager'
    format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value     = data['value']     ? data['value']     : nil

    # defaults
    cacheSize          = 0   # set the cache size in bytes
    cacheLevel         = 0   # cache level in bytes
    cacheInitialLevel  = 0   # initial cache level in bytes
    newGenCacheSize    = 0   # cache size of new generation folder in bytes
    newGenLevel        = 0   # cache level of the new generation in bytes
    newGenInitialLevel = 0   # initial cache level of the new generation in bytes
    oldGenLevel        = 0   # cache level of the old generation in bytes
    oldGenInitialLevel = 0   # initial cache level of the old generation level in bytes
    faultSizeSum       = 0   # sum of sizes in bytes of all blobs faulted since system start
    faultCount         = 0   # count of faults since system start
    recallSizeSum      = 0   # sum of sizes in bytes of all blobs recalled since system start
    recallCount        = 0   # count of recalls since system start
    rotateCount        = 0   # count of rotates since system start
    accessCount        = 0   # count of accesses since system start

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      cacheSize               = value['CacheSize']                 ? value['CacheSize']                 : nil
      cacheLevel              = value['Level']                     ? value['Level']                     : nil
      cacheInitialLevel       = value['InitialLevel']              ? value['InitialLevel']              : nil
      newGenCacheSize         = value['NewGenerationCacheSize']    ? value['NewGenerationCacheSize']    : nil
      newGenCacheLevel        = value['NewGenerationLevel']        ? value['NewGenerationLevel']        : nil
      newGenCacheInitialLevel = value['NewGenerationInitialLevel'] ? value['NewGenerationInitialLevel'] : nil
      oldGenCacheLevel        = value['OldGenerationLevel']        ? value['OldGenerationLevel']        : nil
      oldGenCacheInitialLevel = value['OldGenerationInitialLevel'] ? value['OldGenerationInitialLevel'] : nil
      faultSize               = value['FaultSizeSum']              ? value['FaultSizeSum']              : nil
      fault                   = value['FaultCount']                ? value['FaultCount']                : nil
      recallSize              = value['RecallSizeSum']             ? value['RecallSizeSum']             : nil
      recall                  = value['RecallCount']               ? value['RecallCount']               : nil
      rotate                  = value['RotateCount']               ? value['RotateCount']               : nil
      access                  = value['AccessCount']               ? value['AccessCount']               : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'size'          , @interval, cacheSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'level'         , @interval, cacheLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'initial_level' , @interval, cacheInitialLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'size'          , @interval, newGenCacheSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'level'         , @interval, newGenCacheLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'initial_level' , @interval, newGenCacheInitialLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'level'         , @interval, oldGenCacheLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'initial_level' , @interval, oldGenCacheInitialLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'count'         , @interval, fault ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'size'          , @interval, faultSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'count'         , @interval, recall ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'size'          , @interval, recallSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'rotate'      , 'count'         , @interval, rotate ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'access'      , 'count'         , @interval, access ) )

    return result

  end


  def ParseResult_Memory( data = {} )

    result = []
    mbean  = 'Memory'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    memoryTypes = ['HeapMemoryUsage', 'NonHeapMemoryUsage']

    # defaults
    init      = 0
    max       = 0
    used      = 0
    committed = 0
    percent   = 0


    def memType( m )

      case m
      when 'HeapMemoryUsage'
        type = 'heap_memory'
      else
        type = 'perm_memory'
      end

      return type

    end

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      memoryTypes.each do |m|

        init      = value[m]['init']
        max       = value[m]['max']
        used      = value[m]['used']
        committed = value[m]['committed']

        percent   = ( 100 * used / committed )

        type      = memType( m )

        result.push( sprintf( format, @Host, @Service, mbean, type, 'init'        , @interval, init ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'max'         , @interval, max ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'used'        , @interval, used ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent', @interval, percent ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'committed'   , @interval, committed ) )
      end

    else

      memoryTypes.each do |m|

        type      = memType( m )

        result.push( sprintf( format, @Host, @Service, mbean, type, 'init'        , @interval, init ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'max'         , @interval, max ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'used'        , @interval, used ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent', @interval, percent ) )
        result.push( sprintf( format, @Host, @Service, mbean, type, 'committed'   , @interval, committed ) )
      end
    end

    return result

  end


  def ParseResult_Threading( data = {} )

    result = []
    mbean  = 'Threading'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value'] ? data['value'] : nil

    # defaults
    peak   = 0
    count  = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      peak   = value['PeakThreadCount']  ? value['PeakThreadCount']  : 0
      count  = value['ThreadCount']      ? value['ThreadCount']      : 0

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'threading', 'peak' , @interval, peak ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'threading', 'count', @interval, count ) )

    return result

  end


  def ParseResult_ThreadPool( data = {} )

    # was für komische
    # müssen wir klären

  end


  def ParseResult_ClassLoading( data = {} )

    result = []
    mbean  = 'ClassLoading'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value'] ? data['value'] : nil

    # defaults
    loaded      = 0
    totalLoaded = 0
    unloaded    = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      loaded      = value['LoadedClassCount']      ? value['LoadedClassCount']      : nil
      totalLoaded = value['TotalLoadedClassCount'] ? value['TotalLoadedClassCount'] : nil
      unloaded    = value['UnloadedClassCount']    ? value['UnloadedClassCount']    : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'loaded'  , @interval, loaded ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'total'   , @interval, totalLoaded ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'unloaded', @interval, unloaded ) )

    return result

  end


  def ParseResult_MemoryPool( data = {} )

    result  = []
    mbean   = 'MemoryPool'
    format  = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value   = data['value']    ? data['value']    : nil
    request = data['request']  ? data['request']  : nil
    bean    = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
    usage   = ( value != nil && ['Usage'] )          ? value['Usage']   : nil

    # defaults
    init      = 0
    max       = 0
    used      = 0
    committed = 0
    percent   = 0
    mbeanName = beanName( bean )
    mbeanName = mbeanName.strip.tr( ' ', '_' )

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil && usage != nil )

      init      = usage['init']       ? usage['init']      : nil
      max       = usage['max']        ? usage['max']       : nil
      used      = usage['used']       ? usage['used']      : nil
      committed = usage['committed']  ? usage['committed'] : nil

      if( max != -1 )
        percent   = ( 100 * used / max )
      else
        percent   = ( 100 * used / committed )
      end

    end

    result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'init'        , @interval, init ) )
    result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'committed'   , @interval, committed ) )
    result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'max'         , @interval, max ) )
    result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'used'        , @interval, used ) )
    result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'used_percent', @interval, percent ) )

    return result
  end


  def ParseResult_GCParNew( data = {} )

    result = []
    mbean  = 'GCParNew'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value'] ? data['value'] : nil

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

        # currently not needed
        # activate if you need
#        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|
#
#          case gc
#          when 'memoryUsageBeforeGc'
#            gc_type = 'before'
#          when 'memoryUsageAfterGc'
#            gc_type = 'after'
#          end
#
#          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|
#
#            if( lastGcInfo[gc][type] )
#              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
#              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
#              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
#              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil
#
#              percent   = ( 100 * used / committed )
#
#              type      = type.strip.tr( ' ', '_' ).downcase
#
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'init'        , @interval, init ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'committed'   , @interval, committed ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'max'         , @interval, max ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used'        , @interval, used ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used_percent', @interval, percent ) )
#            end
#         end
#        end

      end
    end

    return result

  end


  def ParseResult_GCConcurrentMarkSweep( data = {} )

    result = []
    mbean  = 'GCConcurrentMarkSweep'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value'] ? data['value'] : nil

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#       value = value.values.first

      lastGcInfo = value['LastGcInfo'] ? value['LastGcInfo']      : nil

      if( lastGcInfo != nil )

        duration      = lastGcInfo['duration']      ? lastGcInfo['duration']      : nil

        result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

        # currently not needed
        # activate if you need
#        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|
#
#          case gc
#          when 'memoryUsageBeforeGc'
#            gc_type = 'before'
#          when 'memoryUsageAfterGc'
#            gc_type = 'after'
#          end
#
#          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|
#
#            if( lastGcInfo[gc][type] )
#              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
#              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
#              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
#              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil
#
#              type      = type.strip.tr( ' ', '_' ).downcase
#
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
#              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
#            end
#          end
#        end

      end
    end

    return result

  end


  def ParseResult_Server( data = {} )

    result       = []
    mbean        = 'Server'
    format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value        = data['value']  ? data['value']  : nil

    # defaults
    cacheHits             = 0
    cacheEvicts           = 0
    cacheEntries          = 0
    cacheInterval         = 0
    cacheSize             = 0
    reqSeqNumber          = nil
    connectionCount       = 0
    runlevel              = nil
    uptime                = nil
    serviceInfos          = nil
    licenseValidFrom      = nil
    licenseValidUntilSoft = nil
    licenseValidUntilHard = nil

    def timeParser( today, finalDate )

      difference = TimeDifference.between( today, finalDate ).in_each_component

      return {
        :years  => difference[:years].round,
        :months => difference[:months].round,
        :weeks  => difference[:weeks].round,
        :days   => difference[:days].round
      }
    end


    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      cacheHits             = value['ResourceCacheHits']        ? value['ResourceCacheHits']         : nil
      cacheEvicts           = value['ResourceCacheEvicts']      ? value['ResourceCacheEvicts']       : nil
      cacheEntries          = value['ResourceCacheEntries']     ? value['ResourceCacheEntries']      : nil
      cacheInterval         = value['ResourceCacheInterval']    ? value['ResourceCacheInterval']     : nil
      cacheSize             = value['ResourceCacheSize']        ? value['ResourceCacheSize']         : nil
      reqSeqNumber          = value['RepositorySequenceNumber'] ? value['RepositorySequenceNumber']  : nil
      connectionCount       = value['ConnectionCount']          ? value['ConnectionCount']           : nil
      runlevel              = value['RunLevel']                 ? value['RunLevel']                  : nil
      uptime                = value['Uptime']                   ? value['Uptime']                    : nil
      serviceInfos          = value['ServiceInfos']             ? value['ServiceInfos']              : nil
      licenseValidFrom      = value['LicenseValidFrom']         ? value['LicenseValidFrom']          : nil
      licenseValidUntilSoft = value['LicenseValidUntilSoft']    ? value['LicenseValidUntilSoft']     : nil
      licenseValidUntilHard = value['LicenseValidUntilHard']    ? value['LicenseValidUntilHard']     : nil

      case runlevel.downcase
        when 'offline'
          runlevel = 0
        when 'online'
          runlevel = 1
        when 'administration'
          runlevel = 11
      else
        runlevel = 0
      end

      if( serviceInfos != nil )

        format = 'PUTVAL %s/%s-%s-%s-%s/count-%s interval=%s N:%s'

        serviceInfos.each do |s,v|

          enabled = v['enabled'] ? v['enabled'] : false

          if( enabled == true )

            named          = v['named']         ? v['named']         : 0
            namedMax       = v['maxnamed']      ? v['maxnamed']      : 0
            namedDiff      = namedMax - named
            concurrent     = v['concurrent']    ? v['concurrent']    : 0
            concurrentMax  = v['maxconcurrent'] ? v['maxconcurrent'] : 0
            concurrentDiff = concurrentMax - concurrent

            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named'          , @interval, named ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_max'      , @interval, namedMax ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_diff'     , @interval, namedDiff ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent'     , @interval, concurrent ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_max' , @interval, concurrentMax ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_diff', @interval, concurrentDiff ) )
          end
        end
      end

      if( licenseValidFrom != nil || licenseValidUntilSoft != nil || licenseValidUntilHard != nil)

        format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
        t      = Date.parse( Time.now().to_s )
        today  = Time.new( t.year, t.month, t.day )

        if( licenseValidFrom != nil )

          result.push( sprintf( format, @Host, @Service, mbean, 'license_from', 'raw'      , @interval, licenseValidFrom / 1000 ) )

        end


        if( licenseValidUntilSoft != nil )

          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'raw'      , @interval, licenseValidUntilSoft / 1000 ) )

          x                   = timeParser( today, Time.at( licenseValidUntilSoft / 1000 ) )
          validUntilSoftMonth = x[:months]
          validUntilSoftWeek  = x[:weeks]
          validUntilSoftDays  = x[:days]

          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'months' , @interval, validUntilSoftMonth ) )
          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'weeks'  , @interval, validUntilSoftWeek ) )
          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'days'   , @interval, validUntilSoftDays ) )

        end

        if( licenseValidUntilHard != nil )

          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'raw'      , @interval, licenseValidUntilHard / 1000 ) )

          x                   = timeParser( today, Time.at( licenseValidUntilHard / 1000 ) )
          validUntilHardMonth = x[:months]
          validUntilHardWeek  = x[:weeks]
          validUntilHardDays  = x[:days]

          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'months' , @interval, validUntilHardMonth ) )
          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'weeks'  , @interval, validUntilHardWeek ) )
          result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'days'   , @interval, validUntilHardDays ) )
        end
      end

    end

    format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'

    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_hits'      , @interval, cacheHits ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_evicts'    , @interval, cacheEvicts ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_entries'   , @interval, cacheEntries ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_interval'  , @interval, cacheInterval ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'cache_size'      , @interval, cacheSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'sequence_number' , @interval, reqSeqNumber ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'connection_count', @interval, connectionCount ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'uptime'          , @interval, uptime ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'runlevel'        , @interval, runlevel ) )

    return result

  end


  def ParseResult_Feeder( data = {} )

    result = []
    mbean  = 'Feeder'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    pendingEvents           = 0
    indexDocuments          = 0
    indexContentDocuments   = 0
    currentPendingDocuments = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      pendingEvents           = value['PendingEvents']              ? value['PendingEvents']              : nil
      indexDocuments          = value['IndexDocuments']             ? value['IndexDocuments']             : nil
      indexContentDocuments   = value['IndexContentDocuments']      ? value['IndexContentDocuments']      : nil
      currentPendingDocuments = value['CurrentPendingDocuments']    ? value['CurrentPendingDocuments']    : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'pending_events'            , @interval, pendingEvents ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_documents'           , @interval, indexDocuments ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )

    return result

  end


  def ParseResult_CacheClasses( key, data = {} )

    result = []
    mbean  = 'CacheClasses'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil
    cacheClass = key.gsub( mbean, '' )

    # defaults
    capacity  = 0
    evaluated = 0
    evicted   = 0
    inserted  = 0
    removed   = 0
    level     = 0
    missRate  = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      capacity  = value['Capacity']    ? value['Capacity']    : nil
      evaluated = value['Evaluated']   ? value['Evaluated']   : nil
      evicted   = value['Evicted']     ? value['Evicted']     : nil
      inserted  = value['Inserted']    ? value['Inserted']    : nil
      removed   = value['Removed']     ? value['Removed']     : nil
      level     = value['Level']       ? value['Level']       : nil
      missRate  = value['MissRate']    ? value['MissRate']    : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'evaluated' , @interval, evaluated ) )
    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'evicted'   , @interval, evicted ) )
    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'inserted'  , @interval, inserted ) )
    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'removed'   , @interval, removed ) )

    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'level'     , @interval, level ) )
    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'capacity'  , @interval, capacity ) )
    result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'missRate'  , @interval, missRate ) )

    return result

  end


  def ParseResult_Health( data = {} )

    result = []
    mbean  = 'Health'
    format = 'PUTVAL %s/%s-%s-%s/gauge-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    healthy = -1 # 0: false, 1: true, -1: N/A

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      healthy   = value['Healthy']  ? value['Healthy'] : nil
      if ( healthy != nil )
        healthy           = healthy == true ? 1 : 0
      end

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'healthy', @interval, healthy ) )

    return result
  end

  # Check for the CAEFeeder
  def ParseResult_ProactiveEngine( data = {} )

    result = []
    mbean  = 'ProactiveEngine'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value'] ? data['value'] : nil

    # defaults
    maxEntries     = 0
    currentEntries = 0
    diffEntries    = 0
    invalidations  = 0
    heartbeat      = 0
    queueCapacity  = 0
    queueMaxSize   = 0
    queueSize      = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      maxEntries     = value['KeysCount']         ? value['KeysCount']         : 0  # Number of (active) keys
      currentEntries = value['ValuesCount']       ? value['ValuesCount']       : 0  # Number of (valid) values. It is less or equal to 'keysCount'
      diffEntries    = ( maxEntries - currentEntries ).to_i

      invalidations  = value['InvalidationCount'] ? value['InvalidationCount'] : nil  # Number of invalidations which have been received
      heartbeat      = value['HeartBeat']         ? value['HeartBeat']         : nil  # The heartbeat of this service: Milliseconds between now and the latest activity. A low value indicates that the service is alive. An constantly increasing value might be caused by a 'sick' or dead service
      queueCapacity  = value['QueueCapacity']     ? value['QueueCapacity']     : nil  # The queue's capacity: Maximum number of items which can be enqueued
      queueMaxSize   = value['QueueMaxSize']      ? value['QueueMaxSize']      : nil  # Maximum number of items which had been waiting in the queue
      queueSize      = value['QueueSize']         ? value['QueueSize']         : nil  # Number of items waiting in the queue for being processed. Less or equal than 'queueCapacity'. Zero means that ProactiveEngine is idle.

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max'          , @interval, maxEntries ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current'      , @interval, currentEntries ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff'         , @interval, diffEntries ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'invalidations', @interval, invalidations ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'heartbeat'    , @interval, heartbeat ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'capacity'     , @interval, queueCapacity ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'max_waiting'  , @interval, queueMaxSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'waiting'      , @interval, queueSize ) )

    return result
  end


  def ParseResult_CapConnection( data = {} )

    result = []
    mbean  = 'CapConnection'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    blobCacheSize    = 0
    blobCacheLevel   = 0
    blobCacheFaults  = 0
    blobCachePercent = 0
    heapCacheSize    = 0
    heapCacheLevel   = 0
    heapCacheFaults  = 0
    heapCachePercent = 0
    suSessions       = 0
    open             = -1 # 0: false, 1: true, -1: N/A

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      blobCacheSize    = value['BlobCacheSize']        ? value['BlobCacheSize']      : nil
      blobCacheLevel   = value['BlobCacheLevel']       ? value['BlobCacheLevel']     : nil
      blobCacheFaults  = value['BlobCacheFaults']      ? value['BlobCacheFaults']    : nil
      blobCachePercent = ( 100 * blobCacheLevel.to_i / blobCacheSize.to_i ).to_i

      heapCacheSize    = value['HeapCacheSize']        ? value['HeapCacheSize']      : nil
      heapCacheLevel   = value['HeapCacheLevel']       ? value['HeapCacheLevel']     : nil
      heapCacheFaults  = value['HeapCacheFaults']      ? value['HeapCacheFaults']    : nil
      heapCachePercent = ( 100 * heapCacheLevel.to_i / heapCacheSize.to_i ).to_i

      suSessions       = value['NumberOfSUSessions']   ? value['NumberOfSUSessions'] : nil

      connectionOpen   = (value['Open']  != nil)       ? value['Open']               : nil
      if ( connectionOpen != nil )
        open           = connectionOpen ? 1 : 0
      end
    end

    result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'size'        , @interval, blobCacheSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used'        , @interval, blobCacheLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'fault'       , @interval, blobCacheFaults ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used_percent', @interval, blobCachePercent ) )

    result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'size'        , @interval, heapCacheSize ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used'        , @interval, heapCacheLevel ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'fault'       , @interval, heapCacheFaults ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used_percent', @interval, heapCachePercent ) )

    result.push( sprintf( format, @Host, @Service, mbean, 'su_sessions', 'sessions'   , @interval, suSessions ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'open'       , 'open'       , @interval, open ) )

    return result

  end


  def ParseResult_SolrReplication( data = {} )

    result    = []
    mbean     = 'Replication'
    format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value     = data['value']    ? data['value']   : nil
    request   = data['request']  ? data['request'] : nil
    solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
    solrCore  = self.solrCore( solrMbean )

    # defaults
    generation        = 0
    isMaster          = 0
    isSlave           = 0
    indexVersion      = 0
    requests          = 0
    medianRequestTime = 0
    errors            = 0
    indexSize         = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#      value = value.values.first

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
      if( indexSize != nil && ( indexSize.include?( 'bytes' ) ) )
        indexSize = indexSize.gsub!( 'ytes','' )
      end
      indexSize         = Filesize.from( indexSize ).to_i

    end

    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index_size', @interval, indexSize.to_s ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index'     , @interval, indexVersion ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'    , @interval, errors ) )

    return result

  end


  def solrCache( mbean, data = {} )

    result    = []
    format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value     = data['value']    ? data['value']   : nil
    request   = data['request']  ? data['request'] : nil
    solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
    solrCore  = self.solrCore( solrMbean )

    # defaults
    warmupTime           = 0
    lookups              = 0
    evictions            = 0
    inserts              = 0
    hits                 = 0
    size                 = 0
    hitratio             = 0
    cumulative_inserts   = 0
    cumulative_hits      = 0
    cumulative_evictions = 0
    cumulative_hitratio  = 0
    cumulative_lookups   = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#      value = value.values.first

      warmupTime           = value['warmupTime']           ? value['warmupTime']           : nil
      lookups              = value['lookups']              ? value['lookups']              : nil
      evictions            = value['evictions']            ? value['evictions']            : nil
      inserts              = value['inserts']              ? value['inserts']              : nil
      hits                 = value['hits']                 ? value['hits']                 : nil
      size                 = value['size']                 ? value['size']                 : nil
      hitratio             = value['hitratio']             ? value['hitratio']             : nil
#      cumulative_inserts   = value['cumulative_inserts']   ? value['cumulative_inserts']   : nil
#      cumulative_hits      = value['cumulative_hits']      ? value['cumulative_hits']      : nil
#      cumulative_evictions = value['cumulative_evictions'] ? value['cumulative_evictions'] : nil
#      cumulative_hitratio  = value['cumulative_hitratio']  ? value['cumulative_hitratio']  : nil
#      cumulative_lookups   = value['cumulative_lookups']   ? value['cumulative_lookups']   : nil
    end

    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'warmupTime'  , @interval, warmupTime ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'lookups'     , @interval, lookups ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'evictions'   , @interval, evictions ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'inserts'     , @interval, inserts ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hits'        , @interval, hits ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'size'        , @interval, size ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hitratio'    , @interval, hitratio ) )

    return result

  end


  def ParseResult_SolrQueryResultCache( data = {} )

    mbean     = 'QueryResultCache'

    return self.solrCache( mbean, data )

  end


  def ParseResult_SolrDocumentCache( data = {} )

    mbean     = 'DocumentCache'

    return self.solrCache( mbean, data )

  end


  def ParseResult_SolrSelect( data = {} )

    result    = []
    mbean     = 'Select'
    format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value     = data['value']    ? data['value']   : nil
    request   = data['request']  ? data['request'] : nil
    solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
    solrCore  = self.solrCore( solrMbean )

    # defaults
    avgRequestsPerSecond   = 0
    avgTimePerRequest      = 0
    medianRequestTime      = 0
    requests               = 0
    timeouts               = 0
    errors                 = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

#      value = value.values.first

      avgRequestsPerSecond   = value['avgRequestsPerSecond']   ? value['avgRequestsPerSecond'] : nil
      avgTimePerRequest      = value['avgTimePerRequest']      ? value['avgTimePerRequest']    : nil
      medianRequestTime      = value['medianRequestTime']      ? value['medianRequestTime']    : nil
      requests               = value['requests']               ? value['requests']             : nil
      timeouts               = value['timeouts']               ? value['timeouts']             : nil
      errors                 = value['errors']                 ? value['errors']               : nil

    end

    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgRequestsPerSecond'  , @interval, avgRequestsPerSecond ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgTimePerRequest'     , @interval, avgTimePerRequest ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'medianRequestTime'     , @interval, medianRequestTime ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'requests'              , @interval, requests ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'timeouts'              , @interval, timeouts ) )
    result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'                , @interval, errors ) )

    return result
  end


  def ParseResult_ConnectionPool( data = {} )

    result = []
    mbean  = 'ConnectionPool'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    open   = 0
    max    = 0
    idle   = 0
    busy   = 0
    min    = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      open   = value['OpenConnections']  ? value['OpenConnections']  : nil
      max    = value['MaxConnections']   ? value['MaxConnections']   : nil
      idle   = value['IdleConnections']  ? value['IdleConnections']  : nil
      busy   = value['BusyConnections']  ? value['BusyConnections']  : nil
      min    = value['MinConnections']   ? value['MinConnections']   : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'open', @interval, open ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'max' , @interval, max ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'idle', @interval, idle ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'busy', @interval, busy ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'min' , @interval, min ) )

    return result

  end


  def ParseResult_QueryPool( data = {} )

    result = []
    mbean  = 'QueryPool'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    executorsRunning = 0
    executorsIdle    = 0
    queriesMax       = 0
    queriesWaiting   = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      executorsRunning = value['RunningExecutors'] ? value['RunningExecutors'] : nil
      executorsIdle    = value['IdleExecutors']    ? value['IdleExecutors']    : nil
      queriesMax       = value['MaxQueries']       ? value['MaxQueries']       : nil
      queriesWaiting   = value['WaitingQueries']   ? value['WaitingQueries']   : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_running', @interval, executorsRunning ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_idle'   , @interval, executorsIdle ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_max'      , @interval, queriesMax ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_waiting'  , @interval, queriesWaiting ) )

    return result

  end


  def ParseResult_StatisticsBlobStoreMethods( data = {} )

    # was für komische Werte kommen da aus JMX raus?
    # müssen wir klären

  end


  def ParseResult_StatisticsJobResult( data = {} )

    result = []
    mbean  = 'StatisticsJobResult'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    failed        = 0
    successful    = 0
    unrecoverable = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      failed        = value['Failed']        ? value['Failed']        : nil
      successful    = value['Successful']    ? value['Successful']    : nil
      unrecoverable = value['Unrecoverable'] ? value['Unrecoverable'] : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'failed'       , @interval, failed ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'successful'   , @interval, successful ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'unrecoverable', @interval, unrecoverable ) )

    return result

  end


  def ParseResult_StatisticsResourceCache( data = {} )

    result = []
    mbean  = 'StatisticsResourceCache'
    format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
    value  = data['value']  ? data['value']  : nil

    # defaults
    size     = 0
    removed  = 0
    faults   = 0
    misses   = 0
    hits     = 0

    if( self.checkBean‎Consistency( mbean, data ) == true && value != nil )

      value = value.values.first

      size     = value['CacheSize']     ? value['CacheSize']     : nil
      removed  = value['CacheRemoved']  ? value['CacheRemoved']  : nil
      faults   = value['CacheFaults']   ? value['CacheFaults']   : nil
      misses   = value['CacheMisses']   ? value['CacheMisses']   : nil
      hits     = value['CacheHits']     ? value['CacheHits']     : nil

    end

    result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'size'   , @interval, size ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'removed', @interval, removed ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'faults' , @interval, faults ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'misses' , @interval, misses ) )
    result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'hits'   , @interval, hits ) )

    return result

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


  def createGraphiteOutput( key, values )

    graphiteOutput = Array.new()

    case key
    when 'Runtime'
      graphiteOutput.push( self.ParseResult_Runtime( values ) )
    when 'OperatingSystem'
      graphiteOutput.push( self.ParseResult_OperatingSystem( values ) )
    when 'Manager'
      graphiteOutput.push( self.ParseResult_TomcatManager( values ) )
    when 'DataViewFactory'
      graphiteOutput.push( self.ParseResult_DataViewFactory( values ) )

    # currently disabled
    # need information or discusion about it
#    when 'TransformedBlobCacheManager'
#      graphiteOutput.push( self.ParseResult_TransformedBlobCacheManager( values ) )
    when 'Memory'
      graphiteOutput.push(self.ParseResult_Memory( values ) )
    when 'MemoryPoolCMSOldGen'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'MemoryPoolCodeCache'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'MemoryPoolCompressedClassSpace'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'MemoryPoolMetaspace'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'MemoryPoolParEdenSpace'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'MemoryPoolParSurvivorSpace'
      graphiteOutput.push(self.ParseResult_MemoryPool( values ) )
    when 'Threading'
      graphiteOutput.push(self.ParseResult_Threading( values ) )
  #    when 'ThreadPool'
  #      graphiteOutput.push( self.ParseResult_ThreadPool( values ) )
    when 'ClassLoading'
      graphiteOutput.push(self.ParseResult_ClassLoading( values ) )
    when 'Server'
      graphiteOutput.push(self.ParseResult_Server( values ) )
    when 'Health'
      graphiteOutput.push(self.ParseResult_Health( values ) )
    when 'ProactiveEngine'
      graphiteOutput.push(self.ParseResult_ProactiveEngine( values ) )
    when 'Feeder'
      graphiteOutput.push(self.ParseResult_Feeder( values ) )
    when /^CacheClasses/
      graphiteOutput.push(self.ParseResult_CacheClasses( key, values ) )
    when 'CapConnection'
      graphiteOutput.push(self.ParseResult_CapConnection( values ) )
    when 'StoreConnectionPool'
      graphiteOutput.push(self.ParseResult_ConnectionPool( values ) )
    when 'StoreQueryPool'
      graphiteOutput.push(self.ParseResult_QueryPool( values ) )
    when 'StatisticsJobResult'
      graphiteOutput.push(self.ParseResult_StatisticsJobResult( values ) )
    when 'StatisticsResourceCache'
      graphiteOutput.push(self.ParseResult_StatisticsResourceCache( values ) )
    when 'GarbageCollectorParNew'
      graphiteOutput.push(self.ParseResult_GCParNew( values ) )
    when 'GarbageCollectorConcurrentMarkSweep'
      graphiteOutput.push(self.ParseResult_GCConcurrentMarkSweep( values ) )
    when /^Solr.*Replication/
      graphiteOutput.push(self.ParseResult_SolrReplication( values ) )
    when /^Solr.*QueryResultCache/
      graphiteOutput.push(self.ParseResult_SolrQueryResultCache( values ) )
    when /^Solr.*DocumentCache/
      graphiteOutput.push(self.ParseResult_SolrDocumentCache( values ) )
    when /^Solr.*Select/
      graphiteOutput.push(self.ParseResult_SolrSelect( values ) )
    end

    return graphiteOutput

  end



  def run()

    monitoredServer = monitoredServer( @cacheDirectory )
#     data            = Hash.new()

    monitoredServer.each do |h|

      @Host = h
      graphiteOutput = Array.new()

      @log.info( sprintf( 'Host: %s', h ) )

      if( @supportMemcache == true )

        resultFile = sprintf( '%s/%s/discovery.json', @cacheDirectory, h )

        if( File.exists?( resultFile ) )

          data = JSON.parse( File.read( resultFile ) )

          data.each do |service, d|

            @Service = normalizeService( service )

            port        = d['port']        ? d['port']        : nil
            description = d['description'] ? d['description'] : nil

            key         = sprintf( 'result__%s__%s', h, service )
            result      = @mc.get( key )

            case service
            when 'mongodb'
              graphiteOutput.push( self.ParseResult_mongoDB( result ) )
            when 'mysql'
              graphiteOutput.push( self.ParseResult_mySQL( result ) )
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
        end
      else

        resultFile = sprintf( '%s/%s/monitoring.result', @cacheDirectory, h )

        if( File.exists?( resultFile ) )

          data = JSON.parse( File.read( resultFile ) )

          hostname  = data[:hostname]  ? data[:hostname]  : nil
          timestamp = data[:timestamp] ? data[:timestamp] : nil
          keys      = data.keys
          keys      -= ['hostname', 'timestamp']

          @log.debug( keys )

          keys.each do |service|

            @Service = normalizeService( service )

            results = data[service]

            case service
            when 'mongodb'
              graphiteOutput.push( self.ParseResult_mongoDB( results ) )
            when 'mysql'
              graphiteOutput.push( self.ParseResult_mySQL( results ) )
            else
              @log.debug( service )

              results.each do |r|

                r.each do |k,v|

                  graphiteOutput = self.createGraphiteOutput( k, v )

                end
              end
            end
          end
        end

      end

      # send to configured graphite host
      self.output( graphiteOutput )
    end

  end

end
