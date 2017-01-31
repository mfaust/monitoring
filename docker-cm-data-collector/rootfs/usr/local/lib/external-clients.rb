#!/usr/bin/ruby

require 'json'
require 'rest-client'
require 'mysql2'

require_relative 'logging'

module ExternalClients

  class MySQL

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

      rescue Exception => e
        logger.error( "An error occurred for connection: #{e}" )

        return false
      end

      return self

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
            hash[ device.to_s ][ type.to_s ] = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )
          end
        end

        r.push( hash )

      end

      result = r.reduce( :merge )

      return result

    end


    def get()

      puts @host
      puts @port

      begin

        self.callService( )

        return {
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

end
