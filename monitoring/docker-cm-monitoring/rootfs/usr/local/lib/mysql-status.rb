#
#
#

require 'mysql2'


class  MysqlStatus

  attr_accessor :mysqlHost, :mysqlPort, :mysqlUser, :mysqlUser

  def initialize( settings = {} )

    @logDirectory      = settings['log_dir']   ? settings['log_dir']   : '/tmp'
    @mysqlHost         = settings['mysqlHost'] ? settings['mysqlHost'] : 'localhost'
    @mysqlPort         = settings['mysqlPort'] ? settings['mysqlPort'] : 3306
    @mysqlUser         = settings['mysqlUser'] ? settings['mysqlUser'] : 'root'
    @mysqlPass         = settings['mysqlPass'] ? settings['mysqlPass'] : ''
    @mysqlQuery        = 'SHOW /*!50002 GLOBAL */ STATUS'

    logFile            = sprintf( '%s/mysql-status.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @relative = false

    self.connect()

  end

  def connect()

    begin
      @client = Mysql2::Client.new(
        :host     => @mysqlHost,
        :username => @mysqlUser,
        :password => @mysqlPass,
        :encoding => 'utf8'
      )

    rescue Exception => e
      @log.error( "An error occurred #{e}" )
    end

  end


  def calculateRelative(rows)
    result = {}
    rows.each do |k,v|
      if @prev_rows[k] && numeric?(v) && isCounter(k)
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

  def toNumeric (value)
    numeric?(value) ? value.to_i : value
  end

  def valuesToNumeric( h )
    Hash[h.map { |k,v| [ k, toNumeric(v)] }]
  end

  # scale the value to be per @interval if recording relative values
  # since it doesn't make much sense to output values that are "per 5 seconds"
  def scaleValue (value)
    (@relative && numeric?(value)) ? (value/@interval) : value
  end

  def scaleValues ( rows )
    Hash[rows.map do |k,v|
      isCounter(k) ? [k, scaleValue(v)] : [k, v]
    end]
  end

  def isCounter (key)
    # list lovingly stolen from pt-mysql-summary
    !%w[ Compression Delayed_insert_threads Innodb_buffer_pool_pages_data
         Innodb_buffer_pool_pages_dirty Innodb_buffer_pool_pages_free
         Innodb_buffer_pool_pages_latched Innodb_buffer_pool_pages_misc
         Innodb_buffer_pool_pages_total Innodb_data_pending_fsyncs
         Innodb_data_pending_reads Innodb_data_pending_writes
         Innodb_os_log_pending_fsyncs Innodb_os_log_pending_writes
         Innodb_page_size Innodb_row_lock_current_waits Innodb_row_lock_time_avg
         Innodb_row_lock_time_max Key_blocks_not_flushed Key_blocks_unused
         Key_blocks_used Last_query_cost Max_used_connections Ndb_cluster_node_id
         Ndb_config_from_host Ndb_config_from_port Ndb_number_of_data_nodes
         Not_flushed_delayed_rows Open_files Open_streams Open_tables
         Prepared_stmt_count Qcache_free_blocks Qcache_free_memory
         Qcache_queries_in_cache Qcache_total_blocks Rpl_status
         Slave_open_temp_tables Slave_running Ssl_cipher Ssl_cipher_list
         Ssl_ctx_verify_depth Ssl_ctx_verify_mode Ssl_default_timeout
         Ssl_session_cache_mode Ssl_session_cache_size Ssl_verify_depth
         Ssl_verify_mode Ssl_version Tc_log_max_pages_used Tc_log_page_size
         Threads_cached Threads_connected Threads_running
         Uptime_since_flush_status ].include? key
  end

  def toJson( data )

    h = Hash.new()

    data.each do |k|

      # "Variable_name"=>"Innodb_buffer_pool_pages_free", "Value"=>"1"
      h[k['Variable_name']] =  k['Value']
    end

    # TODO
    # group-by
#    i = h.select { |k| k[/Innodb.*/] }
#    c = h.select { |k| k[/Com_.*/] }
#
#    h.reject! { |k| k =~ /Innodb.*/ }
#    h.reject! { |k| k =~ /Com_.*/ }
#
#    h['Innodb'] = i
#    h['Com'] = c

    return h

  end


  def run()

    begin

      rs = @client.query( @mysqlQuery )

      rows = self.toJson( rs )
      rows = self.valuesToNumeric( rows )
      rows = self.scaleValues( rows )

      return rows.to_json

    rescue Exception => e
      @log.error( "An error occurred #{e}" )
    end

  end
end
