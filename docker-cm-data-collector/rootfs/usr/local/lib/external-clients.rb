#!/usr/bin/ruby

require 'json'
require 'rest-client'
require 'mysql2'
require 'pg'

require_relative 'logging'



module ExternalClients

  class MySQL

    attr_reader :client

    include Logging

    def initialize( params = {} )

      @mysqlHost  = params[:host]     ? params[:host]     : 'localhost'
      @mysqlPort  = params[:port]     ? params[:port]     : 3306
      @mysqlUser  = params[:username] ? params[:username] : 'root'
      @mysqlPass  = params[:password] ? params[:password] : ''

      @mysqlQuery = 'SHOW /*!50002 GLOBAL */ STATUS'

      @relative   = false
      @client     = nil

      begin
        @client = Mysql2::Client.new(
          :host            => @mysqlHost,
          :username        => @mysqlUser,
          :password        => @mysqlPass,
          :encoding        => 'utf8',
          :reconnect       => true,
          :read_timeout    => 5,
          :connect_timeout => 5
        )
      rescue => e
        logger.error( "An error occurred for connection: #{e}" )
        return nil
      end
      self
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
#      i = h.select { |k| k[/Innodb.*/] }
#      c = h.select { |k| k[/Com_.*/] }
#
#      h.reject! { |k| k =~ /Innodb.*/ }
#      h.reject! { |k| k =~ /Com_.*/ }
#
#      h['Innodb'] = i
#      h['Com'] = c

      return h

    end


    def get()

      if( @client )

        begin

          rs = @client.query( @mysqlQuery )

          if( rs )

            rows = self.toJson( rs )
            rows = self.valuesToNumeric( rows )
            rows = self.scaleValues( rows )

            return rows.to_json
          else
            return false
          end

        rescue Exception => e
          logger.error( "An error occurred for query: #{e}" )
          return false
        end
      end
    end

  end


  class  PostgresStatus

    include Logging

    def initialize( settings = {} )

      logger.debug( settings )

      @logDirectory      = settings['log_dir']        ? settings['log_dir']        : '/tmp'
      @postgresHost      = settings['postgresHost']   ? settings['postgresHost']   : 'localhost'
      @postgresPort      = settings['postgresPort']   ? settings['postgresPort']   : 5432
      @postgresUser      = settings['postgresUser']   ? settings['postgresUser']   : 'root'
      @postgresPass      = settings['postgresPass']   ? settings['postgresPass']   : ''
      @postgresDBName    = settings['postgresDBName'] ? settings['postgresDBName'] : 'test'

    end

    def connect()

      params = {
        :host     => @postgresHost,
        :dbname   => @postgresDBName,
        :user     => @postgresUser,
        :port     => @postgresPort,
        :password => @postgresPass
      }

      begin

###        if( PG::Connection.ping( paranms ) )
        @connection = PG::Connection.new( params )

      rescue PG::Error => e
#        STDERR.puts "An error occurred #{e}"
        logger.error( sprintf( 'An error occurred \'%s\'', e ) )
      end

    end

    def run()

      self.connect()

      begin

        # https://www.postgresql.org/docs/9.6/static/monitoring-stats.html

        # uptime:
        #  SELECT EXTRACT(EPOCH FROM NOW() - stats_reset) from pg_stat_bgwriter;
        # starttime:
        #  SELECT pg_postmaster_start_time();
        # get connectable databases:
        #  SELECT datname FROM pg_database WHERE datallowconn = 't' AND pg_catalog.has_database_privilege(current_user, oid, 'CONNECT')


#
        result  = @connection.send_query( 'select * from pg_stat_database; SELECT * from pg_stat_all_tables where shemaname like \'cm%\';' )
        @connection.set_single_row_mode()

        @connection.get_result.stream_each do |row|

          logger.debug( row )
          # do something with the received row of the first query
        end

        @connection.get_result.stream_each do |row|

          logger.debug( row )
          # do something with the received row of the second query
        end

        @connection.get_result  # => nil   (no more results)

        # ('select * from pg_stat_database')

  #      rows = @sequel[ @mysqlQuery ].to_hash( :Variable_name,:Value )
  #      rows = self.valuesToNumeric(rows)
  #      rows = self.calculateRelative(rows) if @relative
  #      rows = self.scaleValues(rows)
  #      output_query(rows) unless first_run && @relative

      rescue PG::Error => err
        logger.debug( [
            err.result.error_field( PG::Result::PG_DIAG_SEVERITY ),
            err.result.error_field( PG::Result::PG_DIAG_SQLSTATE ),
            err.result.error_field( PG::Result::PG_DIAG_MESSAGE_PRIMARY ),
            err.result.error_field( PG::Result::PG_DIAG_MESSAGE_DETAIL ),
            err.result.error_field( PG::Result::PG_DIAG_MESSAGE_HINT ),
            err.result.error_field( PG::Result::PG_DIAG_STATEMENT_POSITION ),
            err.result.error_field( PG::Result::PG_DIAG_INTERNAL_POSITION ),
            err.result.error_field( PG::Result::PG_DIAG_INTERNAL_QUERY ),
            err.result.error_field( PG::Result::PG_DIAG_CONTEXT ),
            err.result.error_field( PG::Result::PG_DIAG_SOURCE_FILE ),
            err.result.error_field( PG::Result::PG_DIAG_SOURCE_LINE ),
            err.result.error_field( PG::Result::PG_DIAG_SOURCE_FUNCTION ),
        ] )


      rescue Exception => e
#        STDERR.puts "An error occurred #{e}"
        logger.error( sprintf( 'An error occurred \'%s\'', e ) )
      end

    end

  end


  class MongoDb

    include Logging

    def initialize( params = {} )

      @host = params[:host] ? params[:host] : 'localhost'
      @port = params[:port] ? params[:port] : 28017

    end

    def get()

      result = {}

      if( @port != nil )

        serverUrl  = sprintf( 'http://%s:%s/serverStatus', @host, @port )

        uri        = URI.parse( serverUrl )
        http       = Net::HTTP.new( uri.host, uri.port )
        request    = Net::HTTP::Get.new( uri.request_uri )
        request.add_field('Content-Type', 'application/json')

        begin

          response     = http.request( request )

        rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

          logger.error( error )

          case error
          when Errno::EHOSTUNREACH
            logger.error( 'Host unreachable' )
          when Errno::ECONNREFUSED
            logger.error( 'Connection refused' )
          when Errno::ECONNRESET
            logger.error( 'Connection reset' )
          end
        rescue Exception => e

          logger.error( "An error occurred for connection: #{e}" )

        else

          return JSON.parse( response.body )
        end

      end

      return result

    end

  end


  class NodeExporter

    include Logging

    def initialize( params = {} )

      @host      = params[:host]          ? params[:host]          : nil
      @port      = params[:port]          ? params[:port]          : 9100

    end


    def callService()

      uri = URI( sprintf( 'http://%s:%s/metrics', @host, @port ) )

      response = nil

      begin

        Net::HTTP.start( uri.host, uri.port ) do |http|
          request = Net::HTTP::Get.new( uri.request_uri )

          response     = http.request( request )
          responseCode = response.code.to_i

          # TODO
          # Errorhandling
          if( responseCode != 200 )
            logger.error( sprintf( ' [%s] - Error', responseCode ) )
            logger.error( response.body )
          elsif( responseCode == 200 )

            body = response.body
            # remove all comments
            body        = body.each_line.reject{ |x| x.strip =~ /(^.*)#/ }.join

            # get groups
            @boot       = body.each_line.select { |name| name =~ /^node_boot_time/ }
            @cpu        = body.each_line.select { |name| name =~ /^node_cpu/ }
            @disk       = body.each_line.select { |name| name =~ /^node_disk/ }
            @filefd     = body.each_line.select { |name| name =~ /^node_filefd/ }
            @filesystem = body.each_line.select { |name| name =~ /^node_filesystem/ }
            @hwmon      = body.each_line.select { |name| name =~ /^node_hwmon/ }
            @forks      = body.each_line.select { |name| name =~ /^node_forks/ }
            @load       = body.each_line.select { |name| name =~ /^node_load/ }
            @memory     = body.each_line.select { |name| name =~ /^node_memory/ }
            @netstat    = body.each_line.select { |name| name =~ /^node_netstat/ }
            @network    = body.each_line.select { |name| name =~ /^node_network/ }

          end
        end
      rescue Exception => e
  #      logger.error( e )
  #      logger.error( e.backtrace )
        raise( e )

      end

    end


    def collectUptime( data )

      result  = Hash.new()

      parts    = data.last.split( ' ' )

      bootTime = sprintf( "%f", parts[1].to_s ).sub(/\.?0*$/, "" )
      uptime   = Time.at( Time.now() - Time.at( bootTime.to_i ) ).to_i

      result[parts[0]] = bootTime
      result['uptime'] = uptime

      return result
    end


    def collectCpu( data )

      result  = Hash.new()
      tmpCore = nil
      regex   = /(.*){cpu="(?<core>(.*))",mode="(?<mode>(.*))"}(?<mes>(.*))/x

      data.sort!.each do |c|

        if( parts = c.match( regex ) )

          core, mode, mes = parts.captures

          mes = sprintf( "%f", mes.to_s.strip ).sub(/\.?0*$/, "" )

          if( core != tmpCore )
            result[core] = { mode => mes }
            tmpCore = core
          end

          result[core][mode] = mes
        end
      end

      return result
    end


    def collectLoad( data )

      result = Hash.new()
      regex = /(?<load>(.*)) (?<mes>(.*))/x

      data.each do |c|

        if( parts = c.match( regex ) )

          c.gsub!('node_load15', 'longterm' )
          c.gsub!('node_load5' , 'midterm' )
          c.gsub!('node_load1' , 'shortterm' )

          parts = c.split( ' ' )
          result[parts[0]] = parts[1]
        end
      end

      return result
    end


    def collectMemory( data )

      result = Hash.new()
      data   = data.select { |name| name =~ /^node_memory_Swap|node_memory_Mem/ }
      regex  = /(?<load>(.*)) (?<mes>(.*))/x

      data.each do |c|

        if( parts = c.match( regex ) )

          c.gsub!('node_memory_', ' ' )

          parts = c.split( ' ' )
          result[parts[0]] = sprintf( "%f", parts[1].to_s ).sub(/\.?0*$/, "")
        end
      end

      return result
    end


    def collectNetwork( data )

      result = Hash.new()
      r      = Array.new

      existingDevices = Array.new()

      regex = /(.*)receive_bytes{device="(?<device>(.*))"}(.*)/

      d = data.select { |name| name.match( regex ) }

      d.each do |devices|

        if( parts = devices.match( regex ) )
          existingDevices += parts.captures
        end
      end

      regex = /(.*)_(?<direction>(.*))_(?<type>(.*)){device="(?<device>(.*))"}(?<mes>(.*))/x

      existingDevices.each do |d|

        selected = data.select { |name| name.match( /(.*)device="#{d}(.*)/ ) }

        hash = {}

        selected.each do |s|

          if( parts = s.match( regex ) )

            direction, type, device, mes = parts.captures

            hash[ d.to_s ] ||= {}
            hash[ d.to_s ][ direction.to_s ] ||= {}
            hash[ d.to_s ][ direction.to_s ][ type.to_s ] ||= {}
            hash[ d.to_s ][ direction.to_s ][ type.to_s ] = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )
          end
        end

        r.push( hash )

      end

      result = r.reduce( :merge )

      return result

    end


    def collectDisk( data )

      result = Hash.new()
      r      = Array.new

      existingDevices = Array.new()

      regex = /(.*){device="(?<device>(.*))"}(.*)/

      d = data.select { |name| name.match( regex ) }

      d.each do |devices|

        if( parts = devices.match( regex ) )
          existingDevices += parts.captures
        end
      end

      existingDevices.uniq!

      regex = /(.*)_(?<type>(.*))_(?<direction>(.*)){device="(?<device>(.*))"}(?<mes>(.*))/x

      existingDevices.each do |d|

        selected = data.select     { |name| name.match( /(.*)device="#{d}(.*)/ ) }
        selected = selected.select { |name| name =~ /bytes_read|bytes_written|io_now/ }

        hash = {}

        selected.each do |s|

          if( parts = s.match( regex ) )

            type, direction, device, mes = parts.captures

            hash[ d.to_s ] ||= {}
            hash[ d.to_s ][ type.to_s ] ||= {}
            hash[ d.to_s ][ type.to_s ][ direction.to_s ] ||= {}
            hash[ d.to_s ][ type.to_s ][ direction.to_s ] = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )

          end
        end

        r.push( hash )

      end

      result = r.reduce( :merge )

      return result

    end


    def collectFilesystem( data )

      result = Hash.new()
      r      = Array.new

      # blacklist | mount | egrep -v "(cgroup|none|sysfs|devtmpfs|tmpfs|devpts|proc)"
      data.reject! { |t| t[/iso9660/] }
      data.reject! { |t| t[/tmpfs/] }
      data.reject! { |t| t[/rpc_pipefs/] }
      data.reject! { |t| t[/nfs4/] }
      data.reject! { |t| t[/overlay/] }
      data.reject! { |t| t[/cgroup/] }
      data.reject! { |t| t[/devpts/] }
      data.reject! { |t| t[/devtmpfs/] }
      data.reject! { |t| t[/sysfs/] }
      data.reject! { |t| t[/proc/] }
      data.reject! { |t| t[/none/] }
      data.reject! { |t| t[/\/rootfs\/var\/run/] }
      data.flatten!

      existingDevices = Array.new()

      regex = /(.*){device="(?<device>(.*))"}(.*)/

      d = data.select { |name| name.match( regex ) }

      d.each do |devices|

        if( parts = devices.match( regex ) )
          existingDevices += parts.captures
        end
      end

      existingDevices.uniq!

      regex = /(.*)_(?<type>(.*)){device="(?<device>(.*))",fstype="(?<fstype>(.*))",mountpoint="(?<mountpoint>(.*))"}(?<mes>(.*))/x

      existingDevices.each do |d|

        selected = data.select     { |name| name.match( /(.*)device="#{d}(.*)/ ) }

        hash = {}

        selected.each do |s|

          if( parts = s.match( regex ) )

            type, device, fstype, mountpoint, mes = parts.captures

            device.gsub!( '/dev/', '' )

            hash[ device.to_s ] ||= {}
            hash[ device.to_s ][ type.to_s ] ||= {}
            hash[ device.to_s ][ type.to_s ]  = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )
            hash[ device.to_s ]['mountpoint'] = mountpoint
          end
        end

        r.push( hash )

      end

      result = r.reduce( :merge )

      return result

    end


    def get()

      begin

        self.callService( )

        return {
          :uptime     => self.collectUptime( @boot ),
          :cpu        => self.collectCpu( @cpu ),
          :load       => self.collectLoad( @load ),
          :memory     => self.collectMemory( @memory ),
          :network    => self.collectNetwork( @network ),
          :disk       => self.collectDisk( @disk ),
          :filesystem => self.collectFilesystem( @filesystem )
        }
      rescue Exception => e
        logger.error( "An error occurred for query: #{e}" )
        return false
      end

    end

  end


  class Resourced

    include Logging

    def initialize( params = {} )

      @host      = params[:host]          ? params[:host]          : nil
      @port      = params[:port]          ? params[:port]          : 55555

    end


    def network( path )

      uri = URI( sprintf( 'http://%s:%s/r/%s', @host, @port, path ) )

      response = nil
      result   = {}

      begin

        Net::HTTP.start( uri.host, uri.port ) do |http|
          request = Net::HTTP::Get.new( uri.request_uri )

          response     = http.request( request )
          responseCode = response.code.to_i

          # TODO
          # Errorhandling
          if( responseCode != 200 )
            logger.error( sprintf( ' [%s] - Error', responseCode ) )
            logger.error( response.body )
          elsif( responseCode == 200 )

            body = response.body

            result = body.dig( "Data" )

          end
        end

      rescue => e

        logger.error( e )
        logger.error( e.backtrace )

      end

      return result

    end




    def collectLoad( data )

      result = Hash.new()
      regex = /(?<load>(.*)) (?<mes>(.*))/x

      data = self.network( 'load-avg' )

      data.each do |c|

        if( parts = c.match( regex ) )

          c.gsub!('node_load15', 'longterm' )
          c.gsub!('node_load5' , 'midterm' )
          c.gsub!('node_load1' , 'shortterm' )

          parts = c.split( ' ' )
          result[parts[0]] = parts[1]
        end
      end

      return result
    end


    def get()

      puts @host
      puts @port

      begin

        self.callService( )

        return {
          :load       => self.collectLoad( 'load-avg' )
        }

      rescue Exception => e
        logger.error( "An error occurred for query: #{e}" )
        return false
      end

    end


  end


  class ApacheModStatus

    include Logging

    def initialize( params = {} )

      @host  = params.dig(:host)
      @port  = params.dig(:port) || 8081


      # Sample Response with ExtendedStatus On
      # Total Accesses: 20643
      # Total kBytes: 36831
      # CPULoad: .0180314
      # Uptime: 43868
      # ReqPerSec: .470571
      # BytesPerSec: 859.737
      # BytesPerReq: 1827.01
      # BusyWorkers: 6
      # IdleWorkers: 94
      # Scoreboard: ___K_____K____________W_

      @scoreboard_map  = {
        '_' => 'waiting',
        'S' => 'starting',
        'R' => 'reading',
        'W' => 'sending',
        'K' => 'keepalive',
        'D' => 'dns',
        'C' => 'closing',
        'L' => 'logging',
        'G' => 'graceful',
        'I' => 'idle',
        '.' => 'open'
      }

    end


    def get_scoreboard_metrics(response)

      results = Hash.new(0)

      response.slice! 'Scoreboard: '
      response.each_char do |char|
        results[char] += 1
      end

      Hash[results.map { |k, v| [@scoreboard_map[k], v] }]
    end


    def fetch( uri_str, limit = 10 )

      # You should choose better exception.
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      p   = URI::Parser.new
      url = p.parse( uri_str.to_s )

      req      = Net::HTTP::Get.new( "#{url.path}?auto", { 'User-Agent' => 'CoreMedia Monitoring/1.0' })
      response = Net::HTTP.start( url.host, url.port ) { |http| http.request(req) }

      case response
        when Net::HTTPSuccess         then response
        when Net::HTTPRedirection     then fetch( response['location'], limit - 1 )
        when Net::HTTPNotFound        then response
        when Net::HTTPForbidden       then response
      else
        response.error!
      end

    end


    def tick

      a = Array.new

      response = fetch( format('http://%s:%d/server-status', @host, @port), 2 )

      if( response.code.to_i == 200 )

        response = response.body.split("\n")

        # blacklist
        response.reject! { |t| t[/#{@host}/] }
        response.reject! { |t| t[/^Server.*/] }
        response.reject! { |t| t[/.*Time/] }
        response.reject! { |t| t[/^ServerUptime/] }
        response.reject! { |t| t[/^Load.*/] }
        response.reject! { |t| t[/^CPU.*/] }
        response.reject! { |t| t[/^TLSSessionCacheStatus/] }
        response.reject! { |t| t[/^CacheType/] }

        response.each do |line|

          metrics = Hash.new

          if line =~ /Scoreboard/
            metrics = { scoreboard: get_scoreboard_metrics(line.strip) }
          else
            key, value = line.strip.split(':')

            key   = key.gsub(/\s/, '')
            value = value.strip

            metrics[key] = format( "%f", value ).sub(/\.?0*$/, "" ).to_f
          end

          a << metrics
        end

        a.reduce( :merge )

      else
        return {}
      end

    end
  end


  class HttpVhosts

    include Logging

    def initialize( params = {} )

      @host  = params.dig(:host)
      @port  = params.dig(:port) || 8081
    end


    def fetch( uri_str, limit = 10 )

      # You should choose better exception.
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      url = URI.parse(uri_str)
      req = Net::HTTP::Get.new(url.path, { 'User-Agent' => 'CoreMedia Monitoring/1.0' })
      response = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }

      case response
        when Net::HTTPSuccess         then response
        when Net::HTTPRedirection     then fetch(response['location'], limit - 1)
        when Net::HTTPNotFound        then response
      else
        response.error!
      end

    end


    def tick

      response = fetch( format('http://%s:%d/vhosts.json', @host, @port), 2 )

      if( response.code.to_i == 200 )
        return response.body
      else
        return {}
      end

    end
  end


end
