
module CarbonData

  module Database

    module MySQL

      def database_mysql( value = {} )

        result = []

        unless( value.nil? )

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
            key: format( '%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime' ),
            value: uptime
          } << {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'network', 'bytes', 'tx' ),
            value: bytesReceived
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'network', 'bytes', 'rx' ),
            value: bytesSent
          } <<  {
            key: format( '%s.%s.%s'         , @identifier, @normalized_service_name, 'connections' ),
            value: connections
          } <<  {
            key: format( '%s.%s.%s'         , @identifier, @normalized_service_name, 'queries' ),
            value: queries
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'disk_tables' ),
            value: createdTmpDiskTables
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'files' ),
            value: createdTmpFiles
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'tables' ),
            value: createdTmpTables
          } << {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'qcache', 'free', 'blocks' ),
            value: qcacheFreeBlocks
          } << {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'qcache', 'free', 'memory' ),
            value: qcacheFreeMemory
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'hits' ),
            value: qcacheHits
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'inserts' ),
            value: qcacheInserts
          } << {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'low_mem_prunes' ),
            value: qcacheLowmemPrunes
          } << {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'not_cached' ),
            value: qcacheNotCached
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'queries_in_cache' ),
            value: qcacheQueriesInCache
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'total_blocks' ),
            value: qcacheTotalBlocks
          } << {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'cached' ),
            value: threadsCached
          } << {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'connected' ),
            value: threadsConnected
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'created' ),
            value: threadsCreated
          } <<  {
            key: format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'running' ),
            value: threadsRunning
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'data' ),
            value: innodbBufferPoolPagesData
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'dirty' ),
            value: innodbBufferPoolPagesDirty
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'flushed' ),
            value: innodbBufferPoolPagesFlushed
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'free' ),
            value: innodbBufferPoolPagesFree
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'misc' ),
            value: innodbBufferPoolPagesMisc
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'total' ),
            value: innodbBufferPoolPagesTotal
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'data' ),
            value: innodbBufferPoolBytesData
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'dirty' ),
            value: innodbBufferPoolBytesDirty
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead' ),
            value: innodbBufferPoolReadAhead
          } <<  {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead_rnd' ),
            value: innodbBufferPoolReadAheadRnd
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead_evicted' ),
            value: innodbBufferPoolReadAheadEviced
          } << {
            key: format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'requests' ),
            value: innodbBufferPoolReadRequests
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'page', 'size' ),
            value: innodbPageSize
          } <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'created' ),
            value: innodbPagesCreated
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'read' ),
            value: innodbPagesRead
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'written' ),
            value: innodbPagesWritten
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'deleted' ),
            value: innodbRowsDeleted
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'inserted' ),
            value: innodbRowsInserted
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'read' ),
            value: innodbRowsRead
          }  <<  {
            key: format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'updated' ),
            value: innodbRowsUpdated
          }
        end

        result
      end

    end
  end
end
