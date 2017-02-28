module CarbonData

  module OperationSystgem



    def ParseResult_nodeExporter( value = {} )

      format = 'PUTVAL %s/%s-%s/%s-%s interval=%s N:%s'
      result = []

      if( value != nil )

  #      logger.debug( JSON.pretty_generate( value ) )

        cpu        = value.dig('cpu')
        load       = value.dig('load')
        memory     = value.dig('memory')
        filesystem = value.dig('filesystem')

        if( cpu != nil )

          n = cpu.values.inject { |m, el| m.merge( el ) { |k, old_v, new_v| old_v.to_i + new_v.to_i } }

          cpu.each do |c,d|

            ['idle','iowait','nice','system','user'].each do |m|

              point = d.dig( m )

              if( point != nil )
                # collectd.h3_xanhaem_de.cpu.*.cpu.idle.value
                result.push( sprintf( 'PUTVAL %s/%s-cpu/count-%s_%s interval=%s N:%s', @Host, @Service, c, m, @interval, point ) )
  ##              result.push( sprintf( 'PUTVAL %s/%s-%s/cpu_%s interval=%s N:%s', @Host, @Service, c, m, @interval, point ) )
              end
            end
          end
        end


        if( load != nil )

          ['shortterm','midterm','longterm'].each do |m|

            point = load.dig( m ) # [m] ? load[m] : nil

            if( point != nil )
              result.push( sprintf( format, @Host, @Service, 'load', 'count', m, @interval, point ) )
            end
          end
        end


        if( memory != nil )

          memAvailable    = memory.dig('MemAvailable')
          memFree         = memory.dig('MemFree')
          memTotal        = memory.dig('MemTotal')
          memUsed         = ( memTotal.to_i - memAvailable.to_i )
          memUsedPercent  = ( 100 * memUsed.to_i / memTotal.to_i ).to_i

          swapTotal       = memory.dig('SwapTotal')

          if( swapTotal == 0 )
            swapCached      = 0
            swapFree        = 0
            swapUsed        = 0
            swapUsedPercent = 0
          else

            swapCached      = memory.dig('SwapCached')
            swapFree        = memory.dig('SwapFree')
            swapUsed        = ( swapTotal.to_i - swapFree.to_i )

            if( swapUsed.to_i > 0 && swapTotal.to_i > 0 )
              swapUsedPercent = ( 100 * swapUsed.to_i / swapTotal.to_i ).to_i
            else
              swapUsedPercent = 0
            end

          end

          result.push( sprintf( format, @Host, @Service, 'memory', 'count', 'available'    , @interval, memAvailable ) )
          result.push( sprintf( format, @Host, @Service, 'memory', 'count', 'free'         , @interval, memFree ) )
          result.push( sprintf( format, @Host, @Service, 'memory', 'count', 'total'        , @interval, memTotal ) )
          result.push( sprintf( format, @Host, @Service, 'memory', 'count', 'used'         , @interval, memUsed ) )
          result.push( sprintf( format, @Host, @Service, 'memory', 'count', 'used_percent' , @interval, memUsedPercent ) )

          result.push( sprintf( format, @Host, @Service, 'swap'  , 'count', 'cached'       , @interval, swapCached ) )
          result.push( sprintf( format, @Host, @Service, 'swap'  , 'count', 'free'         , @interval, swapFree ) )
          result.push( sprintf( format, @Host, @Service, 'swap'  , 'count', 'total'        , @interval, swapTotal ) )
          result.push( sprintf( format, @Host, @Service, 'swap'  , 'count', 'used'         , @interval, swapUsed ) )
          result.push( sprintf( format, @Host, @Service, 'swap'  , 'count', 'used_percent' , @interval, swapUsedPercent ) )

        end


        if( filesystem != nil )

          format = 'PUTVAL %s/%s-filesystem/count-%s_%s interval=%s N:%s'

          filesystem.each do |f,d|

            avail = d.dig('avail')
            size  = d.dig('size')

            used         = ( size.to_i - avail.to_i )
            usedPercent  = ( 100 * used.to_i / size.to_i ).to_i

            result.push( sprintf( format, @Host, @Service, f, 'total'        , @interval, size ) )
            result.push( sprintf( format, @Host, @Service, f, 'free'         , @interval, avail ) )
            result.push( sprintf( format, @Host, @Service, f, 'used'         , @interval, used ) )
            result.push( sprintf( format, @Host, @Service, f, 'used_percent' , @interval, usedPercent ) )
          end
        end


  #  "network": {
  #    "docker0": {
  #      "receive": {
  #        "bytes": "0",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "0",
  #        "packets": "0"
  #      },
  #      "transmit": {
  #        "bytes": "0",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "0",
  #        "packets": "0"
  #      }
  #    },
  #    "eth0": {
  #      "receive": {
  #        "bytes": "150430429312",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "7",
  #        "packets": "676887217"
  #      },
  #      "transmit": {
  #        "bytes": "232584909545",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "0",
  #        "packets": "651601311"
  #      }
  #    },
  #    "lo": {
  #      "receive": {
  #        "bytes": "42496402339",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "0",
  #        "packets": "102897397"
  #      },
  #      "transmit": {
  #        "bytes": "42496402339",
  #        "compressed": "0",
  #        "drop": "0",
  #        "errs": "0",
  #        "fifo": "0",
  #        "frame": "0",
  #        "multicast": "0",
  #        "packets": "102897397"
  #      }
  #    }
  #  },
  #  "disk": {
  #    "dm-0": {
  #      "bytes": {
  #        "read": "328886272",
  #        "written": "229814784"
  #      },
  #      "io": {
  #        "now": "0"
  #      }
  #    },
  #    "sda": {
  #      "bytes": {
  #        "read": "1764546560",
  #        "written": "71720772096"
  #      },
  #      "io": {
  #        "now": "0"
  #      }
  #    },
  #    "sr0": {
  #      "bytes": {
  #        "read": "0",
  #        "written": "0"
  #      },
  #      "io": {
  #        "now": "0"
  #      }
  #    }
  #  },
  #  "filesystem": {
  #    "/dev/sda1": {
  #      "avail": "32145022976",
  #      "files": "41936640",
  #      "free": "32145022976",
  #      "readonly": "0",
  #      "size": "42932649984"
  #    }
  #  }
  #}

      end

      return result

    end


  end

end
