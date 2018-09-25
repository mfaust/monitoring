
module ExternalClients

  module MySQL

    class Instance

      include Logging

      attr_reader :client

      def initialize( params = {} )

        @mysql_host     = params.dig(:host) || 'localhost'
        @mysql_port     = params.dig(:port) || 3306
        @mysql_user     = params.dig(:username) || 'monitoring'
        @mysql_password = params.dig(:password) || 'monitoring'

        @mysql_query = 'SHOW /*!50002 GLOBAL */ STATUS'

        @relative   = false
        @client     = nil

        connect

        self
      end


      def connect

        logger.debug("connect to #{@mysql_host}:#{@mysql_port}")

#         logger.debug(@client.inspect)

        begin
          @client = Mysql2::Client.new(
            host: @mysql_host,
            username: @mysql_user,
            password: @mysql_password,
            encoding: 'utf8',
            reconnect: false,
            read_timeout: 5,
            connect_timeout: 5
          )
        rescue => error
          logger.error( "An error occurred for connection: #{error}" )
          return nil
        end
      end


      def calculate_relative(rows)
        result = {}
        rows.each do |k,v|
          if @prev_rows[k] && numeric?(v) && is_counter(k)
            result[k] = v - @prev_rows[k]
          else
            result[k] = v
          end
        end
        @prev_rows = rows
        return result
      end


      def numeric? (value)
        true if Float(value) rescue false
      end

      def to_numeric (value)
        numeric?(value) ? value.to_i : value
      end

      def values_to_numeric( h )
        Hash[h.map { |k,v| [ k, to_numeric(v)] }]
      end

      # scale the value to be per @interval if recording relative values
      # since it doesn't make much sense to output values that are "per 5 seconds"
      def scale_value (value)
        (@relative && numeric?(value)) ? (value/@interval) : value
      end

      def scale_values ( rows )
        Hash[rows.map do |k,v|
          is_counter(k) ? [k, scale_value(v)] : [k, v]
        end]
      end

      def is_counter (key)
        # list lovingly stolen from pt-mysql-summary
        !%w[ Compression
            Delayed_insert_threads
            Innodb_buffer_pool_pages_data
            Innodb_buffer_pool_pages_dirty
            Innodb_buffer_pool_pages_free
            Innodb_buffer_pool_pages_latched
            Innodb_buffer_pool_pages_misc
            Innodb_buffer_pool_pages_total
            Innodb_data_pending_fsyncs
            Innodb_data_pending_reads
            Innodb_data_pending_writes
            Innodb_os_log_pending_fsyncs
            Innodb_os_log_pending_writes
            Innodb_page_size
            Innodb_row_lock_current_waits
            Innodb_row_lock_time_avg
            Innodb_row_lock_time_max
            Key_blocks_not_flushed
            Key_blocks_unused
            Key_blocks_used
            Last_query_cost
            Max_used_connections
            Ndb_cluster_node_id
            Ndb_config_from_host
            Ndb_config_from_port
            Ndb_number_of_data_nodes
            Not_flushed_delayed_rows
            Open_files
            Open_streams
            Open_tables
            Prepared_stmt_count
            Qcache_free_blocks
            Qcache_free_memory
            Qcache_queries_in_cache
            Qcache_total_blocks
            Rpl_status
            Slave_open_temp_tables
            Slave_running
            Ssl_cipher
            Ssl_cipher_list
            Ssl_ctx_verify_depth
            Ssl_ctx_verify_mode
            Ssl_default_timeout
            Ssl_session_cache_mode
            Ssl_session_cache_size
            Ssl_verify_depth
            Ssl_verify_mode Ssl_version
            Tc_log_max_pages_used
            Tc_log_page_size
            Threads_cached
            Threads_connected
            Threads_running
            Uptime_since_flush_status ].include? key
      end

      def to_json( data )

        h = {}

        data.each do |k|
          # "Variable_name"=>"Innodb_buffer_pool_pages_free", "Value"=>"1"
          h[k['Variable_name']] =  k['Value']
        end

        # TODO
        # group-by
#        i = h.select { |k| k[/Innodb.*/] }
#        c = h.select { |k| k[/Com_.*/] }
#
#        h.reject! { |k| k =~ /Innodb.*/ }
#        h.reject! { |k| k =~ /Com_.*/ }
#
#        h['Innodb'] = i
#        h['Com'] = c

        h
      end


      def get()

        rows = nil
        rs   = nil

#         logger.debug( 'get mysql data' )

        connect if(@client.nil?)
        return false if(@client.nil?)

#         logger.debug(@client.inspect)

        if(@client.is_a?(Mysql2::Client))
          begin
            rs = @client.query( @mysql_query )
          rescue Exception => error
            logger.error( "An error occurred for query: #{error}" )
          end

          @client.close
          @client = nil
        end

        logger.debug(rs.inspect)

        if(rs.is_a?(Mysql2::Result))
          rows = to_json( rs )
          rows = values_to_numeric( rows )
          rows = scale_values( rows ).to_json
          # logger.debug( JSON.pretty_generate( rows ) )
        end

        logger.debug( "rows: #{rows} (#{rows.class})" )

        rows
      end

    end
  end

end
