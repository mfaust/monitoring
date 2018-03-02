
module CarbonData

  module OperatingSystem

    module NodeExporter

      def operating_system_node_exporter( value = {} )

        result = []

        unless( value.nil? )

          uptime     = value.dig('uptime')
          cpu        = value.dig('cpu')
          load       = value.dig('load')
          memory     = value.dig('memory')
          filesystem = value.dig('filesystem')

          unless( uptime.nil? )

            boot_time = uptime.dig('node_boot_time')
            uptime    = uptime.dig('uptime')

            unless( boot_time.nil? )
              result << {
                key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime', 'boot_time' ),
                value: boot_time
              }
            end

            unless( uptime.nil? )
              result << {
                key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'uptime', 'uptime' ),
                value: uptime
              }
            end
          end


          unless( cpu.nil? )

            n = cpu.values.inject { |m, el| m.merge( el ) { |k, old_v, new_v| old_v.to_i + new_v.to_i } }

            cpu.each do |c,d|

              ['idle','iowait','nice','system','user'].each do |m|

                point = d.dig( m )

                unless( point.nil? )

                  result << {
                    key: format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'cpu', c, m ),
                    value: point
                  }
                end
              end
            end
          end


          unless( load.nil? )

            ['shortterm','midterm','longterm'].each do |m|

              point = load.dig( m ) # [m] ? load[m] : nil

              unless( point.nil? )

                result << {
                  key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'load', m ),
                  value: point
                }
              end
            end
          end


          unless( memory.nil? )

            memory_available    = memory.dig('MemAvailable')
            memory_free         = memory.dig('MemFree')
            memory_total        = memory.dig('MemTotal')
            memory_used         = ( memory_total.to_i - memory_available.to_i )
            memory_used_percent = ( 100 * memory_used.to_i / memory_total.to_i ).to_i

            swap_total          = memory.dig('SwapTotal')
            swap_cached         = 0
            swap_free           = 0
            swap_used           = 0
            swap_used_percent   = 0

            if( swap_total != 0 )
              swap_cached       = memory.dig('SwapCached')
              swap_free         = memory.dig('SwapFree')
              swap_used         = ( swap_total.to_i - swap_free.to_i )
              swap_used_percent = ( 100 * swap_used.to_i / swap_total.to_i ).to_i if( swap_used.to_i > 0 && swap_total.to_i > 0 )
            end

            result << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'available' ),
              value: memory_available
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'free' ),
              value: memory_free
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'total' ),
              value: memory_total
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'used' ),
              value: memory_used
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'memory', 'used_percent' ),
              value: memory_used_percent
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'cached' ),
              value: swap_cached
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'free' ),
              value: swap_free
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'total' ),
              value: swap_total
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'used' ),
              value: swap_used
            } << {
              key: format( '%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'swap', 'used_percent' ),
              value: swap_used_percent
            }

          end


          unless( filesystem.nil? )

            filesystem.each do |f,d|

              avail = d.dig('avail')
              size  = d.dig('size')

              if( size.to_i == 0 )
                logger.debug( 'zero size' )
                logger.debug( d )
                next
              end

              used         = ( size.to_i - avail.to_i )
              used_percent  = ( 100 * used.to_i / size.to_i ).to_i

              result << {
                key: format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'total' ),
                value: size
              } << {
                key: format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'free' ),
                value: avail
              } << {
                key: format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'used' ),
                value: used
              } << {
                key: format( '%s.%s.%s.%s.%s'         , @identifier, @normalized_service_name, 'filesystem', f, 'used_percent' ),
                value: used_percent
              }

            end
          end

        end

        result

      end

    end

  end

end
