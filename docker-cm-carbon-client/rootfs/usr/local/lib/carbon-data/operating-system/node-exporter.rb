
module CarbonData

  module OperatingSystem

    module NodeExporter

      def operatingSystemNodeExporter( value = {} )

        result = []

        if( value != nil )

          uptime     = value.dig('uptime')
          cpu        = value.dig('cpu')
          load       = value.dig('load')
          memory     = value.dig('memory')
          filesystem = value.dig('filesystem')

          if( uptime != nil )

            boot_time = uptime.dig('node_boot_time')
            uptime    = uptime.dig('uptime')

            if( boot_time != nil )
              result << {
                :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime', 'boot_time' ),
                :value => boot_time
              }
            end
            if( uptime != nil )
              result << {
                :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime', 'uptime' ),
                :value => uptime
              }
            end
          end


          if( cpu != nil )

            n = cpu.values.inject { |m, el| m.merge( el ) { |k, old_v, new_v| old_v.to_i + new_v.to_i } }

            cpu.each do |c,d|

              ['idle','iowait','nice','system','user'].each do |m|

                point = d.dig( m )

                if( point != nil )

                  result << {
                    :key   => format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'cpu', c, m ),
                    :value => point
                  }
                end
              end
            end
          end


          if( load != nil )

            ['shortterm','midterm','longterm'].each do |m|

              point = load.dig( m ) # [m] ? load[m] : nil

              if( point != nil )

                result << {
                  :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'load', m ),
                  :value => point
                }
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

            result << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'available' ),
              :value => memAvailable
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'free' ),
              :value => memFree
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'total' ),
              :value => memTotal
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'used' ),
              :value => memUsed
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'used_percent' ),
              :value => memUsedPercent
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'cached' ),
              :value => swapCached
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'free' ),
              :value => swapFree
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'total' ),
              :value => swapTotal
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'used' ),
              :value => swapUsed
            } << {
              :key   => format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'used_percent' ),
              :value => swapUsedPercent
            }

          end


          if( filesystem != nil )

            filesystem.each do |f,d|

              avail = d.dig('avail')
              size  = d.dig('size')

              if( size.to_i == 0 )
                logger.debug( 'zero size' )
                logger.debug( d )
                next
              end

              used         = ( size.to_i - avail.to_i )
              usedPercent  = ( 100 * used.to_i / size.to_i ).to_i

              result << {
                :key   => format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'total' ),
                :value => size
              } << {
                :key   => format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'free' ),
                :value => avail
              } << {
                :key   => format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'used' ),
                :value => used
              } << {
                :key   => format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'used_percent' ),
                :value => usedPercent
              }

            end
          end

        end

        return result

      end

    end

  end

end
