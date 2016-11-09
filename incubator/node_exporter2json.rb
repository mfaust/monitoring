#!/usr/bin/ruby

require 'json'
require 'net/http'
require 'rest-client'

class String
  def strip_comment( markers = ['#',';'] )
    re = Regexp.union( markers ) # construct a regular expression which will match any of the markers
    if index = (self =~ re)
      self[0, index].rstrip      # slice the string where the regular expression matches, and return it.
    else
      rstrip
    end
  end
end



    restClient = RestClient::Resource.new(
      URI.encode( sprintf( 'http://localhost:9100/metrics' ) )
    )

data = restClient.get()

body = data.body

# remove all comments
body       = body.each_line.reject{ |x| x.strip =~ /(^.*)#/ }.join

# get groups
cpu        = body.each_line.select { |name| name =~ /^node_cpu/ }
disk       = body.each_line.select { |name| name =~ /^node_disk/ }
filefd     = body.each_line.select { |name| name =~ /^node_filefd/ }
filesystem = body.each_line.select { |name| name =~ /^node_filesystem/ }
hwmon      = body.each_line.select { |name| name =~ /^node_hwmon/ }
forks      = body.each_line.select { |name| name =~ /^node_forks/ }
load       = body.each_line.select { |name| name =~ /^node_load/ }
memory     = body.each_line.select { |name| name =~ /^node_memory/ }
netstat    = body.each_line.select { |name| name =~ /^node_netstat/ }
network    = body.each_line.select { |name| name =~ /^node_network/ }




def collectCpu( data )

  regex = /(.*){cpu="(?<core>(.*))",mode="(?<mode>(.*))"}(?<mes>(.*))/x

  result = Hash.new()

  core_save = nil
  data.sort!.each do |c|

    if( parts = c.match( regex ) )

      core, mode, mes = parts.captures

      mes.strip!

      if( core != core_save )
        result[core] = { mode => mes }
        core_save = core
      end

      result[core][mode] = mes
    end
  end

  return JSON.pretty_generate( Hash[result.sort] )
end

def collectLoad( data )

  regex = /(?<load>(.*)) (?<mes>(.*))/x

  result = Hash.new()

  data.each do |c|

    if( parts = c.match( regex ) )

      c.gsub!('node_load15', 'longterm' )
      c.gsub!('node_load5' , 'midterm' )
      c.gsub!('node_load1' , 'shortterm' )

      parts = c.split( ' ' )
      result[parts[0]] = parts[1]
    end
  end

  return JSON.pretty_generate( Hash[result.sort] )
end

def collectMemory( data )

  regex = /(?<load>(.*)) (?<mes>(.*))/x

  result = Hash.new()

  data = data.select { |name| name =~ /^node_memory_Swap|node_memory_Mem/ }

  data.each do |c|

    if( parts = c.match( regex ) )

      c.gsub!('node_memory_', ' ' )

      parts = c.split( ' ' )
      result[parts[0]] = sprintf( "%f", parts[1].to_s ).sub(/\.?0*$/, "")
    end
  end

  return JSON.pretty_generate( Hash[result.sort] )

end

def collectNetwork( data )

  regex = /(.*)_(?<direction>(.*))_(?<type>(.*)){device="(?<device>(.*))"}(?<mes>(.*))/x

  result = Hash.new()
  r = Array.new

  device_save = nil
  type_save = nil
  existingDevices = Array.new()

  d = data.select { |name| name.match( /(.*)receive_bytes{device="(?<device>(.*))"}(.*)/ ) }

  d.each do |devices|

    if( parts = devices.match( /(.*)receive_bytes{device="(?<device>(.*))"}(.*)/ ) )
      existingDevices += parts.captures
    end
  end

  existingDevices.each do |d|

    r = Array.new

    [ 'receive','transmit' ].each do |t|

#      puts t

      selected = data.select { |name| name.match( /(.*)#{t}(.*)device="#{d}(.*)/ ) }
#      puts selected

      hash = {}

      selected.each do |s|

        if( parts = s.match( regex ) )

          direction, type, device, mes = parts.captures

#           puts sprintf( '%s : %s : %s -> %s', device, direction, type, sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" ) )

          hash[ d.to_s ] ||= {}
          hash[ d.to_s ][ t.to_s ] ||= {}
          hash[ d.to_s ][ t.to_s ][ type.to_s ] ||= {}
          hash[ d.to_s ][ t.to_s ][ type.to_s ] = sprintf( "%f", mes.to_s ).sub(/\.?0*$/, "" )
        end
      end

      r.push( hash )
    end

def collect_values a
  a.map(&:to_a).flatten(1).group_by{|k, v| k}.
  each_value{|v| v.map!{|k, v| v}}
end

#     result = {}.tap{ |x| r.each{ |h| h.each{ |k,v| (x[k]||=[]) << v } } } #.map( &:to_a ).flatten(1).reduce( {} ) { |h,(k,v)| ( h[k] ||= [] ) << v; h }

    result2 = Hash[*r.map(&:to_a).flatten(1)]

#     hash = Hash[*r.flatten]

#     puts JSON.pretty_generate( result )
    puts JSON.pretty_generate( result2 )
  end

#  result = r.reduce( :merge ).keys

#  puts r.flatten
#  return JSON.pretty_generate( r.merge )
end


# puts collectCpu( cpu )
# puts collectLoad( load )
# puts collectMemory( memory )


puts collectNetwork( network )

#node_network_receive_bytes{device="eth0"} 98635
#node_network_receive_bytes{device="lo"} 0
#node_network_receive_compressed{device="eth0"} 0
#node_network_receive_compressed{device="lo"} 0
#node_network_receive_drop{device="eth0"} 0
#node_network_receive_drop{device="lo"} 0
#node_network_receive_errs{device="eth0"} 0
#node_network_receive_errs{device="lo"} 0
#node_network_receive_fifo{device="eth0"} 0
#node_network_receive_fifo{device="lo"} 0
#node_network_receive_frame{device="eth0"} 0
#node_network_receive_frame{device="lo"} 0
#node_network_receive_multicast{device="eth0"} 0
#node_network_receive_multicast{device="lo"} 0
#node_network_receive_packets{device="eth0"} 1064
#node_network_receive_packets{device="lo"} 0
#node_network_transmit_bytes{device="eth0"} 1.912721e+06
#node_network_transmit_bytes{device="lo"} 0
#node_network_transmit_compressed{device="eth0"} 0
#node_network_transmit_compressed{device="lo"} 0
#node_network_transmit_drop{device="eth0"} 0
#node_network_transmit_drop{device="lo"} 0
#node_network_transmit_errs{device="eth0"} 0
#node_network_transmit_errs{device="lo"} 0
#node_network_transmit_fifo{device="eth0"} 0
#node_network_transmit_fifo{device="lo"} 0
#node_network_transmit_frame{device="eth0"} 0
#node_network_transmit_frame{device="lo"} 0
#node_network_transmit_multicast{device="eth0"} 0
#node_network_transmit_multicast{device="lo"} 0
#node_network_transmit_packets{device="eth0"} 775
#node_network_transmit_packets{device="lo"} 0
#