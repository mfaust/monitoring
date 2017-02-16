#!/usr/bin/ruby
#
#
# reads and parse the f*ing output of prometheus' node_exporter
# then put the result as json
#
#  (c) 2016 Coremedia (Bodo Schulz)
#

require 'json'
require 'rest-client'

require 'logger'

# -------------------------------------------------------------------------------------------------

module Logging

  def logger
    @logger ||= Logging.logger_for( self.class.name )
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for( classname )
      @loggers[classname] ||= configure_logger_for( classname )
    end

    def configure_logger_for( classname )

      logger                 = Logger.new(STDOUT)
      logger.progname        = classname
      logger.level           = Logger::DEBUG
      logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      logger.formatter       = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime( logger.datetime_format )}] #{severity.ljust(5)} : #{progname} - #{msg}\n"
      end

      logger
    end
  end
end

# -------------------------------------------------------------------------------------------------


class NodeExporter

  include Logging

  def initialize( )

  end

  def callService()

    restClient = RestClient::Resource.new(
      URI.encode( sprintf( 'http://%s:%s/metrics', @host, @port ) )
    )

    data = restClient.get()
    body = data.body

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


  def collectUptime( data )

    result  = Hash.new()
    tmpCore = nil

    logger.debug( data.class.to_s )

        parts = data.last.split( ' ' )

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

        mes.strip!

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

    # blacklist
    data.reject! { |t| t[/iso9660/] }
    data.reject! { |t| t[/tmpfs/] }
    data.reject! { |t| t[/rpc_pipefs/] }
    data.reject! { |t| t[/nfs4/] }
    data.reject! { |t| t[/overlay/] }
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

          hash[ device.to_s ] ||= {}
          hash[ device.to_s ][ type.to_s ] ||= {}
          hash[ device.to_s ][ type.to_s ] = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )
          hash[ device.to_s ]['mountpoint'] = mountpoint
        end
      end

      r.push( hash )

    end

    result = r.reduce( :merge )

    return result

  end


  def run( settings = {} )

    @host      = settings[:host]          ? settings[:host]          : nil
    @port      = settings[:port]          ? settings[:port]          : nil

    puts @host
    puts @port

    self.callService( )

    return {
      :uptime     => self.collectUptime( @boot ),
#       :cpu        => self.collectCpu( @cpu ),
#       :load       => self.collectLoad( @load ),
#       :memory     => self.collectMemory( @memory ),
#       :network    => self.collectNetwork( @network ),
#       :disk       => self.collectDisk( @disk ),
      :filesystem => self.collectFilesystem( @filesystem )
    }

  end

end

# -------------------------------------------------------------------------------------------------
# example

options = {
  :host => 'release-1701-tomcat',
  :port => '9100'
}

x = NodeExporter.new()
puts JSON.pretty_generate( x.run( options ) )

# -------------------------------------------------------------------------------------------------
