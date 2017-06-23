
module CarbonData

  module Http

    module Apache

      def http_server_status( value = {} )

        result = []

        unless(value.nil?)

          total_accesses         = value.dig('TotalAccesses') || 0
          total_kbytes           = value.dig('TotalkBytes')   || 0
          uptime                 = value.dig('Uptime') || 0
          req_per_sec            = value.dig('ReqPerSec') || 0
          bytes_per_sec          = value.dig('BytesPerSec') || 0
          bytes_per_req          = value.dig('BytesPerReq') || 0
          busy_workers           = value.dig('BusyWorkers') || 0
          idle_workers           = value.dig('IdleWorkers') || 0
          conns_total            = value.dig('ConnsTotal') || 0
          conns_async_writing    = value.dig('ConnsAsyncWriting') || 0
          conns_async_keep_alive = value.dig('ConnsAsyncKeepAlive') || 0
          conns_async_closing    = value.dig('ConnsAsyncClosing') || 0
          sb_waiting             = value.dig('waiting') || 0
          sb_sending             = value.dig('sending') || 0
          sb_open                = value.dig('open') || 0
          sb_starting            = value.dig('starting') || 0
          sb_reading             = value.dig('reading') || 0
          sb_keepalive           = value.dig('keepalive') || 0
          sb_dns                 = value.dig('dns') || 0
          sb_closing             = value.dig('closing') || 0
          sb_logging             = value.dig('logging') || 0
          sb_graceful            = value.dig('graceful') || 0
          sb_idle                = value.dig('idle') || 0
          cache_shared_memory    = value.dig('CacheSharedMemory') || 0
          cache_current_entries  = value.dig('CacheCurrentEntries') || 0
          cache_subcaches        = value.dig('CacheSubcaches') || 0
          cache_index_per_subcache = value.dig('CacheIndexesPerSubcaches') || 0
          cache_index_usage      = value.dig('CacheIndexUsage') || 0
          cache_usage            = value.dig('CacheUsage') || 0
          cache_store            = value.dig('CacheStoreCount') || 0
          cache_replace          = value.dig('CacheReplaceCount') || 0
          cache_expire           = value.dig('CacheExpireCount') || 0
          cache_discard          = value.dig('CacheDiscardCount') || 0
          cache_retrieve_hit     = value.dig('CacheRetrieveHitCount') || 0
          cache_retrieve_miss    = value.dig('CacheRetrieveMissCount') || 0
          cache_remove_hit       = value.dig('CacheRemoveHitCount') || 0
          cache_remove_miss      = value.dig('CacheRemoveMissCount') || 0

          result << {
            :key   => sprintf( '%s.%s.%s'      , @identifier, @Service, 'uptime' ),
            :value => uptime
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'workers', 'busy' ),
            :value => busy_workers
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'workers', 'idle' ),
            :value => idle_workers
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'waiting' ),
            :value => sb_waiting
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'sending' ),
            :value => sb_sending
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'open' ),
            :value => sb_open
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'starting' ),
            :value => sb_starting
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'reading' ),
            :value => sb_reading
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'keepalive' ),
            :value => sb_keepalive
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'dns' ),
            :value => sb_dns
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'closing' ),
            :value => sb_closing
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'logging' ),
            :value => sb_logging
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'graceful' ),
            :value => sb_graceful
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'scoreboard', 'idle' ),
            :value => sb_idle
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'bytes', 'per_sec' ),
            :value => bytes_per_sec
          } << {
            :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, 'bytes', 'per_req' ),
            :value => bytes_per_req
          }

        end

        result

      end
    end
  end
end
