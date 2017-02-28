
module CarbonData

  module MySQL


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

  end

end
