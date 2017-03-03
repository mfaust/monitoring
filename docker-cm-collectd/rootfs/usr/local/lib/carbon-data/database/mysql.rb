
module CarbonData

  module MySQL


    def ParseResult_mySQL( value = {} )

      format = 'PUTVAL %s/%s-%s/%s-%s interval=%s N:%s'
      result = []

      if( value != nil )

        # READ THIS : http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html

        bytesReceived                   = value.dig('Bytes_received')
        bytesSent                       = value.dig('Bytes_sent')
        connections                     = value.dig('Connections')
        createdTmpDiskTables            = value.dig('Created_tmp_disk_tables')
        createdTmpFiles                 = value.dig('Created_tmp_files')
        createdTmpTables                = value.dig('Created_tmp_tables')
        handlerCommit                   = value.dig('Handler_commit')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Handler_commit
        handlerDelete                   = value.dig('Handler_delete')
        handlerDiscover                 = value.dig('Handler_discover')
        handlerPrepare                  = value.dig('Handler_prepare')
        handlerReadFirst                = value.dig('Handler_read_first')
        handlerReadKey                  = value.dig('Handler_read_key')
        handlerReadLast                 = value.dig('Handler_read_last')
        handlerReadNext                 = value.dig('Handler_read_next')
        handlerReadPrev                 = value.dig('Handler_read_prev')
        handlerReadRnd                  = value.dig('Handler_read_rnd')
        handlerReadRndNext              = value.dig('Handler_read_rnd_next')
        handlerRollback                 = value.dig('Handler_rollback')
        handlerSavepoint                = value.dig('Handler_savepoint')
        handlerSavepointRollback        = value.dig('Handler_savepoint_rollback')
        handlerUpdate                   = value.dig('Handler_update')
        handlerWrite                    = value.dig('Handler_write')
        qcacheFreeBlocks                = value.dig('Qcache_free_blocks')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Qcache_free_blocks
        qcacheFreeMemory                = value.dig('Qcache_free_memory')
        qcacheHits                      = value.dig('Qcache_hits')
        qcacheInserts                   = value.dig('Qcache_inserts')
        qcacheLowmemPrunes              = value.dig('Qcache_lowmem_prunes')
        qcacheNotCached                 = value.dig('Qcache_not_cached')
        qcacheQueriesInCache            = value.dig('Qcache_queries_in_cache')
        qcacheTotalBlocks               = value.dig('Qcache_total_blocks')
        questions                       = value.dig('Questions')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Questions
        queries                         = value.dig('Queries')
        threadsCached                   = value.dig('Threads_cached')
        threadsConnected                = value.dig('Threads_connected')
        threadsCreated                  = value.dig('Threads_created')
        threadsRunning                  = value.dig('Threads_running')
        uptime                          = value.dig('Uptime')

        innodbBufferPoolPagesData       = value.dig('Innodb_buffer_pool_pages_data')
        innodbBufferPoolPagesDirty      = value.dig('Innodb_buffer_pool_pages_dirty')
        innodbBufferPoolPagesFlushed    = value.dig('Innodb_buffer_pool_pages_flushed')
        innodbBufferPoolPagesFree       = value.dig('Innodb_buffer_pool_pages_free')
        innodbBufferPoolPagesMisc       = value.dig('Innodb_buffer_pool_pages_misc')
        innodbBufferPoolPagesTotal      = value.dig('Innodb_buffer_pool_pages_total')
        innodbBufferPoolBytesData       = value.dig('Innodb_buffer_pool_bytes_data')
        innodbBufferPoolBytesDirty      = value.dig('Innodb_buffer_pool_bytes_dirty')
        innodbBufferPoolReadAheadRnd    = value.dig('Innodb_buffer_pool_read_ahead_rnd')
        innodbBufferPoolReadAhead       = value.dig('Innodb_buffer_pool_read_ahead')
        innodbBufferPoolReadAheadEviced = value.dig('Innodb_buffer_pool_read_ahead_evicted')
        innodbBufferPoolReadRequests    = value.dig('Innodb_buffer_pool_read_requests')
        innodbBufferPoolReads           = value.dig('Innodb_buffer_pool_reads')
        innodbBufferPoolWaitFree        = value.dig('Innodb_buffer_pool_wait_free')
        innodbBufferPoolWriteRequests   = value.dig('Innodb_buffer_pool_write_requests')
        innodbPageSize                  = value.dig('Innodb_page_size')
        innodbPagesCreated              = value.dig('Innodb_pages_created')
        innodbPagesRead                 = value.dig('Innodb_pages_read')
        innodbPagesWritten              = value.dig('Innodb_pages_written')
        innodbRowsDeleted               = value.dig('Innodb_rows_deleted')
        innodbRowsInserted              = value.dig('Innodb_rows_inserted')
        innodbRowsRead                  = value.dig('Innodb_rows_read')
        innodbRowsUpdated               = value.dig('Innodb_rows_updated')

        result << {
          :key   => sprintf( '%s.%s.%s'         , @Host, @Service, 'uptime' ),
          :value => uptime
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'network', 'bytes', 'tx' ),
          :value => bytesReceived
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'network', 'bytes', 'rx' ),
          :value => bytesSent
        } <<  {
          :key   => sprintf( '%s.%s.%s'         , @Host, @Service, 'connections' ),
          :value => connections
        } <<  {
          :key   => sprintf( '%s.%s.%s'         , @Host, @Service, 'queries' ),
          :value => queries
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'created', 'tmp', 'disk_tables' ),
          :value => createdTmpDiskTables
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'created', 'tmp', 'files' ),
          :value => createdTmpFiles
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'created', 'tmp', 'tables' ),
          :value => createdTmpTables
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'qcache', 'free', 'blocks' ),
          :value => qcacheFreeBlocks
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'qcache', 'free', 'memory' ),
          :value => qcacheFreeMemory
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'hits' ),
          :value => qcacheHits
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'inserts' ),
          :value => qcacheInserts
        } << {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'low_mem_prunes' ),
          :value => qcacheLowmemPrunes
        } << {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'not_cached' ),
          :value => qcacheNotCached
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'queries_in_cache' ),
          :value => qcacheQueriesInCache
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'qcache', 'total_blocks' ),
          :value => qcacheTotalBlocks
        } << {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'threads', 'cached' ),
          :value => threadsCached
        } << {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'threads', 'connected' ),
          :value => threadsConnected
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'threads', 'created' ),
          :value => threadsCreated
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, 'threads', 'running' ),
          :value => threadsRunning
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'data' ),
          :value => innodbBufferPoolPagesData
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'dirty' ),
          :value => innodbBufferPoolPagesDirty
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'flushed' ),
          :value => innodbBufferPoolPagesFlushed
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'free' ),
          :value => innodbBufferPoolPagesFree
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'misc' ),
          :value => innodbBufferPoolPagesMisc
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'total' ),
          :value => innodbBufferPoolPagesTotal
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'data' ),
          :value => innodbBufferPoolBytesData
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'pages', 'dirty' ),
          :value => innodbBufferPoolBytesDirty
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'read', 'ahead' ),
          :value => innodbBufferPoolReadAhead
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'read', 'ahead_rnd' ),
          :value => innodbBufferPoolReadAheadRnd
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'read', 'ahead_evicted' ),
          :value => innodbBufferPoolReadAheadEviced
        } << {
          :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, 'innodb', 'buffer_pool', 'read', 'requests' ),
          :value => innodbBufferPoolReadRequests
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'page', 'size' ),
          :value => innodbPageSize
        } <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'pages', 'created' ),
          :value => innodbPagesCreated
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'pages', 'read' ),
          :value => innodbPagesRead
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'pages', 'written' ),
          :value => innodbPagesWritten
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'rows', 'deleted' ),
          :value => innodbRowsDeleted
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'rows', 'inserted' ),
          :value => innodbRowsInserted
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'rows', 'read' ),
          :value => innodbRowsRead
        }  <<  {
          :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, 'innodb', 'rows', 'updated' ),
          :value => innodbRowsUpdated
        }








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
