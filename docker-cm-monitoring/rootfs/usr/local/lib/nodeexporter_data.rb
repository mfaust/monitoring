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

class NodeExporter

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


  def run( settings = {} )

    @host      = settings[:host]          ? settings[:host]          : nil
    @port      = settings[:port]          ? settings[:port]          : 9100

#    puts @host
#    puts @port

    self.callService( )

    return {
      :cpu        => self.collectCpu( @cpu ),
      :load       => self.collectLoad( @load ),
      :memory     => self.collectMemory( @memory ),
      :network    => self.collectNetwork( @network ),
      :disk       => self.collectDisk( @disk ),
      :filesystem => self.collectFilesystem( @filesystem )
    }

  end

end

# -------------------------------------------------------------------------------------------------
# example

# options = {
#   :host => '10.2.10.211',
#   :port => '9100'
# }
#
# x = NodeExporter.new()
# puts JSON.pretty_generate( x.run( options ) )

# -------------------------------------------------------------------------------------------------

