
module CarbonData

  module Database

    module MySQL

      def database_mysql( value = {} )

        result = []

        unless( value.nil? )

          logger.debug(JSON.pretty_generate value)

          result += innodb_values(value.select { |k| k[/Innodb.*/] })
          result += thread_values(value.select { |k| k[/Threads.*/] })
          result += qcache_values(value.select { |k| k[/Qcache.*/] })
          result += handler_values(value.select { |k| k[/Handler.*/] })
          result += command_values(value.select { |k| k[/Com.*/] })

          # READ THIS : http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html

          uptime                               = value.dig('Uptime')
          bytes_received                       = value.dig('Bytes_received')
          bytes_sent                           = value.dig('Bytes_sent')
          connections                          = value.dig('Connections')        # The number of connection attempts (successful or not) to the MySQL server.
          connection_errors_internal           = value.dig('Connection_errors_internal')
          connection_errors_max_connections    = value.dig('Connection_errors_max_connections')

          created_tmp_disk_tables              = value.dig('Created_tmp_disk_tables')
          created_tmp_files                    = value.dig('Created_tmp_files')
          created_tmp_tables                   = value.dig('Created_tmp_tables')

          open_files                           = value.dig('Open_files')         # https://mariadb.com/kb/en/library/server-status-variables/#opened_table_definitions
          open_streams                         = value.dig('Open_streams')
          open_tables                          = value.dig('Open_tables')
          open_table_definitions               = value.dig('Open_table_definitions')

          opened_files                         = value.dig('Opened_files')         # https://mariadb.com/kb/en/library/server-status-variables/#opened_table_definitions
          opened_streams                       = value.dig('Opened_streams')
          opened_tables                        = value.dig('Opened_tables')
          opened_table_definitions             = value.dig('Opened_table_definitions')

          questions                            = value.dig('Questions')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Questions
          queries                              = value.dig('Queries')

          locked_connects                      = value.dig('Locked_connects')

          select_full_join                     = value.dig('Select_full_join')
          select_full_range_join               = value.dig('Select_full_range_join')
          select_range                         = value.dig('Select_range')
          select_range_check                   = value.dig('Select_range_check')
          select_scan                          = value.dig('Select_scan')

          slow_queries                         = value.dig('Slow_queries')
          sort_merge_passes                    = value.dig('Sort_merge_passes')
          sort_range                           = value.dig('Sort_range')
          sort_rows                            = value.dig('Sort_rows')
          sort_scan                            = value.dig('Sort_scan')

          table_locks_immediate                = value.dig('Table_locks_immediate')
          table_locks_waited                   = value.dig('Table_locks_waited')
          table_open_cache_hits                = value.dig('Table_open_cache_hits')
          table_open_cache_misses              = value.dig('Table_open_cache_misses')
          table_open_cache_overflows           = value.dig('Table_open_cache_overflows')

          result << {
              key: format('%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime')                                        , value: uptime
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'network', 'bytes', 'tx')                        , value: bytes_received
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'network', 'bytes', 'rx')                        , value: bytes_sent
            } << { key: format('%s.%s.%s'         , @identifier, @normalized_service_name, 'connections')                                   , value: connections
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'connection', 'errors', 'internal')              , value: connection_errors_internal
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'connection', 'errors', 'max_connections')       , value: connection_errors_max_connections
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'open', 'files')                                 , value: open_files
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'open', 'streams')                               , value: open_streams
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'open', 'tables')                                , value: open_tables
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'open', 'table_definitions')                     , value: open_table_definitions
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'opened', 'files')                               , value: opened_files
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'opened', 'streams')                             , value: opened_streams
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'opened', 'tables')                              , value: opened_tables
            } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'opened', 'table_definitions')                   , value: opened_table_definitions
            } << { key: format('%s.%s.%s'         , @identifier, @normalized_service_name, 'queries')                                       , value: queries
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'disk_tables')                 , value: created_tmp_disk_tables
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'files')                       , value: created_tmp_files
            } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'created', 'tmp', 'tables')                      , value: created_tmp_tables
            }


        end

        result.reject! { |k| k[:value].nil? }
      end


      private
      def innodb_values(value)

        result = []

        innodb_buffer_pool_pages_data        = value.dig('Innodb_buffer_pool_pages_data')
        innodb_buffer_pool_pages_dirty       = value.dig('Innodb_buffer_pool_pages_dirty')
        innodb_buffer_pool_pages_flushed     = value.dig('Innodb_buffer_pool_pages_flushed')
        innodb_buffer_pool_pages_free        = value.dig('Innodb_buffer_pool_pages_free')
        innodb_buffer_pool_pages_misc        = value.dig('Innodb_buffer_pool_pages_misc')
        innodb_buffer_pool_pages_total       = value.dig('Innodb_buffer_pool_pages_total')
        innodb_buffer_pool_bytes_data        = value.dig('Innodb_buffer_pool_bytes_data')
        innodb_buffer_pool_bytes_dirty       = value.dig('Innodb_buffer_pool_bytes_dirty')
        innodb_buffer_pool_read_ahead_rnd    = value.dig('Innodb_buffer_pool_read_ahead_rnd')
        innodb_buffer_pool_read_ahead        = value.dig('Innodb_buffer_pool_read_ahead')
        innodb_buffer_pool_read_ahead_eviced = value.dig('Innodb_buffer_pool_read_ahead_evicted')
        innodb_buffer_pool_read_requests     = value.dig('Innodb_buffer_pool_read_requests')
        innodb_buffer_pool_reads             = value.dig('Innodb_buffer_pool_reads')
        innodb_buffer_pool_wait_free         = value.dig('Innodb_buffer_pool_wait_free')
        innodb_buffer_pool_write_requests    = value.dig('Innodb_buffer_pool_write_requests')

        innodb_page_size                     = value.dig('Innodb_page_size')
        innodb_pages_created                 = value.dig('Innodb_pages_created')
        innodb_pages_read                    = value.dig('Innodb_pages_read')
        innodb_pages_written                 = value.dig('Innodb_pages_written')
        innodb_rows_deleted                  = value.dig('Innodb_rows_deleted')
        innodb_rows_inserted                 = value.dig('Innodb_rows_inserted')
        innodb_rows_read                     = value.dig('Innodb_rows_read')
        innodb_rows_updated                  = value.dig('Innodb_rows_updated')
        innodb_num_open_files                = value.dig('Innodb_num_open_files')

        innodb_data_fsyncs                   = value.dig('Innodb_data_fsyncs')
        innodb_data_pending_fsyncs           = value.dig('Innodb_data_pending_fsyncs')
        innodb_data_pending_reads            = value.dig('Innodb_data_pending_reads')
        innodb_data_pending_writes           = value.dig('Innodb_data_pending_writes')

        innodb_data_read                     = value.dig('Innodb_data_read')
        innodb_data_reads                    = value.dig('Innodb_data_reads')
        innodb_data_writes                   = value.dig('Innodb_data_writes')
        innodb_data_written                  = value.dig('Innodb_data_written')
        innodb_dblwr_pages_written           = value.dig('Innodb_dblwr_pages_written')
        innodb_dblwr_writes                  = value.dig('Innodb_dblwr_writes')
        innodb_log_waits                     = value.dig('Innodb_log_waits')
        innodb_log_write_requests            = value.dig('Innodb_log_write_requests')
        innodb_log_writes                    = value.dig('Innodb_log_writes')
        innodb_os_log_fsyncs                 = value.dig('Innodb_os_log_fsyncs')
        innodb_os_log_pending_fsyncs         = value.dig('Innodb_os_log_pending_fsyncs')
        innodb_os_log_pending_writes         = value.dig('Innodb_os_log_pending_writes')
        innodb_os_log_written                = value.dig('Innodb_os_log_written')
        innodb_row_lock_current_waits        = value.dig('Innodb_row_lock_current_waits')
        innodb_row_lock_time                 = value.dig('Innodb_row_lock_time')
        innodb_row_lock_time_avg             = value.dig('Innodb_row_lock_time_avg')
        innodb_row_lock_time_max             = value.dig('Innodb_row_lock_time_max')
        innodb_row_lock_waits                = value.dig('Innodb_row_lock_waits')
        innodb_rows_deleted                  = value.dig('Innodb_rows_deleted')
        innodb_rows_inserted                 = value.dig('Innodb_rows_inserted')
        innodb_rows_read                     = value.dig('Innodb_rows_read')
        innodb_rows_updated                  = value.dig('Innodb_rows_updated')

        result << {
          key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'data')        , value: innodb_buffer_pool_pages_data
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'dirty')       , value: innodb_buffer_pool_pages_dirty
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'flushed')     , value: innodb_buffer_pool_pages_flushed
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'free')        , value: innodb_buffer_pool_pages_free
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'misc')        , value: innodb_buffer_pool_pages_misc
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'total')       , value: innodb_buffer_pool_pages_total
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'data')        , value: innodb_buffer_pool_bytes_data
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'pages', 'dirty')       , value: innodb_buffer_pool_bytes_dirty
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead')        , value: innodb_buffer_pool_read_ahead
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead_rnd')    , value: innodb_buffer_pool_read_ahead_rnd
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'ahead_evicted'), value: innodb_buffer_pool_read_ahead_eviced
        } << { key: format('%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, 'innodb', 'buffer_pool', 'read', 'requests')     , value: innodb_buffer_pool_read_requests
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'page', 'size')                        , value: innodb_page_size
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'created')                    , value: innodb_pages_created
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'read')                       , value: innodb_pages_read
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'pages', 'written')                    , value: innodb_pages_written
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'deleted')                     , value: innodb_rows_deleted
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'inserted')                    , value: innodb_rows_inserted
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'read')                        , value: innodb_rows_read
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'rows', 'updated')                     , value: innodb_rows_updated
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'innodb', 'num', 'open_files')                   , value: innodb_num_open_files
        }

        result
      end


      def thread_values(value)

        result = []

        threads_cached                       = value.dig('Threads_cached')
        threads_connected                    = value.dig('Threads_connected')
        threads_created                      = value.dig('Threads_created')
        threads_running                      = value.dig('Threads_running')

        result << {
           key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'cached')                             , value: threads_cached
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'connected')                          , value: threads_connected
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'created')                            , value: threads_created
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'threads', 'running')                            , value: threads_running
        }

        result
      end


      def qcache_values(value)

        result = []

        qcache_free_blocks                   = value.dig('Qcache_free_blocks')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Qcache_free_blocks
        qcache_free_memory                   = value.dig('Qcache_free_memory')
        qcache_hits                          = value.dig('Qcache_hits')
        qcache_inserts                       = value.dig('Qcache_inserts')
        qcache_lowmem_prunes                 = value.dig('Qcache_lowmem_prunes')
        qcache_not_cached                    = value.dig('Qcache_not_cached')
        qcache_queries_in_cache              = value.dig('Qcache_queries_in_cache')
        qcache_total_blocks                  = value.dig('Qcache_total_blocks')

        result << {
          key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'qcache', 'free', 'blocks')                      , value: qcache_free_blocks
        } << { key: format('%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, 'qcache', 'free', 'memory')                      , value: qcache_free_memory
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'hits')                                , value: qcache_hits
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'inserts')                             , value: qcache_inserts
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'lowmem_prunes')                       , value: qcache_lowmem_prunes
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'not_cached')                          , value: qcache_not_cached
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'queries_in_cache')                    , value: qcache_queries_in_cache
        } << { key: format('%s.%s.%s.%s'      , @identifier, @normalized_service_name, 'qcache', 'total_blocks')                        , value: qcache_total_blocks
        }

        result
      end


      def handler_values(value)

        result = []

          handler_commit                       = value.dig('Handler_commit')    # http://dev.mysql.com/doc/refman/5.7/en/server-status-variables.html#statvar_Handler_commit
          handler_delete                       = value.dig('Handler_delete')
          handler_discover                     = value.dig('Handler_discover')
          handler_prepare                      = value.dig('Handler_prepare')
          handler_read_first                   = value.dig('Handler_read_first')
          handler_read_key                     = value.dig('Handler_read_key')
          handler_read_last                    = value.dig('Handler_read_last')
          handler_read_next                    = value.dig('Handler_read_next')
          handler_read_prev                    = value.dig('Handler_read_prev')
          handler_read_rnd                     = value.dig('Handler_read_rnd')
          handler_read_rnd_next                = value.dig('Handler_read_rnd_next')
          handler_rollback                     = value.dig('Handler_rollback')
          #handler_savepoint                    = value.dig('Handler_savepoint')
          #handler_savepoint_rollback           = value.dig('Handler_savepoint_rollback')
          handler_update                       = value.dig('Handler_update')
          handler_write                        = value.dig('Handler_write')

        result
      end


      def command_values(value)

        result = []

          commands_alter_database              = value.dig('Com_alter_db')
          commands_commit                      = value.dig('Com_commit')
          commands_create_database             = value.dig('Com_create_db')
          commands_create_index                = value.dig('Com_create_index')
          commands_table                       = value.dig('Com_create_table')
          commands_delete                      = value.dig('Com_delete')
          commands_delete_multi                = value.dig('Com_delete_multi')
          commands_drop_database               = value.dig('Com_drop_db')
          commands_drop_index                  = value.dig('Com_drop_index')
          commands_drop_table                  = value.dig('Com_drop_table')
          commands_grant                       = value.dig('Com_grant')
          commands_insert                      = value.dig('Com_insert')
          commands_insert_select               = value.dig('Com_insert_select')
          commands_lock_tables                 = value.dig('Com_lock_tables')
          commands_purge                       = value.dig('Com_purge')
          commands_replace                     = value.dig('Com_replace')
          commands_replace_select              = value.dig('Com_replace_select')
          commands_rollback                    = value.dig('Com_rollback')
          commands_select                      = value.dig('Com_select')
          commands_set_option                  = value.dig('Com_set_option')
          commands_truncate                    = value.dig('Com_truncate')
          commands_unlock_tables               = value.dig('Com_unlock_tables')
          commands_update                      = value.dig('Com_update')
          commands_update_multi                = value.dig('Com_update_multi')

        result
      end




    end
  end
end
