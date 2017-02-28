
module CarbonData

  module Tomcat

    def ParseResult_Runtime( data = {} )

      result    = []
      mbean     = 'Runtime'
#       format    = 'PUTVAL %s/%s-%s-%s/%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      uptime  = 0
      start   = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        uptime   = value.dig('Uptime')
        start    = value.dig('StartTime')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'uptime' ),
        :value => uptime
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'starttime' ),
        :value => start
      }
#       result.push( sprintf( format, @Host, @Service, mbean, 'uptime'   , 'uptime', @interval, uptime ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'starttime', 'gauge' , @interval, start ) )

      return result
    end


    def ParseResult_OperatingSystem( data = {} )

      result    = []
      mbean     = 'OperatingSystem'
#       format    = 'PUTVAL %s/%s-%s-%s/%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      physicalMemorySizeTotal    = 0
      physicalMemorySizeFree     = 0
      virtualMemorySizeCommitted = 0
      swapSpaceSizeTotal         = 0
      swapSpaceSizeFree          = 0
      systemLoadAverage          = 0
      systemCpuLoad              = 0
      fileDescriptorCountMax     = 0
      fileDescriptorCountOpen    = 0
      vvailableProcessors        = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        logger.debug( value )

  #       value = value.values.first
      end

  #     result.push( sprintf( format, @Host, @Service, mbean, 'uptime'   , 'uptime', @interval, uptime ) )
  #     result.push( sprintf( format, @Host, @Service, mbean, 'starttime', 'gauge' , @interval, start ) )

      return result




  #             "value" : {
  #                "TotalPhysicalMemorySize" : 10317664256,
  #                "SystemLoadAverage" : 9.23,
  #                "Arch" : "amd64",
  #                "ProcessCpuLoad" : 0.00165745856353591,
  #                "MaxFileDescriptorCount" : 4096,
  #                "AvailableProcessors" : 2,
  #                "OpenFileDescriptorCount" : 82,
  #                "FreePhysicalMemorySize" : 138825728,
  #                "TotalSwapSpaceSize" : 0,
  #                "ObjectName" : {
  #                   "objectName" : "java.lang:type=OperatingSystem"
  #                },
  #                "CommittedVirtualMemorySize" : 3045675008,
  #                "Name" : "Linux",
  #                "Version" : "3.10.0-327.22.2.el7.x86_64",
  #                "ProcessCpuTime" : 277100000000,
  #                "SystemCpuLoad" : 0.986195472114854,
  #                "FreeSwapSpaceSize" : 0
  #             },



    end


    def ParseResult_TomcatManager( data = {} )

      result    = []
      mbean     = 'Manager'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      processingTime          = 0       # Time spent doing housekeeping and expiration
      duplicates              = 0       # Number of duplicated session ids generated
      maxActiveSessions       = 0       # The maximum number of active Sessions allowed, or -1 for no limit
      sessionMaxAliveTime     = 0       # Longest time an expired session had been alive
      maxInactiveInterval     = 3600    # The default maximum inactive interval for Sessions created by this Manager
      sessionExpireRate       = 0       # Session expiration rate in sessions per minute
      sessionAverageAliveTime = 0       # Average time an expired session had been alive
      rejectedSessions        = 0       # Number of sessions we rejected due to maxActive beeing reached
      processExpiresFrequency = 0       # The frequency of the manager checks (expiration and passivation)
      activeSessions          = 0       # Number of active sessions at this moment
      sessionCreateRate       = 0       # Session creation rate in sessions per minute
      expiredSessions         = 0       # Number of sessions that expired ( doesn't include explicit invalidations )
      sessionCounter          = 0       # Total number of sessions created by this manager
      maxActive               = 0       # Maximum number of active sessions so far

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        duplicates              = value.dig('duplicates')
        maxActiveSessions       = value.dig('maxActiveSessions')
        sessionMaxAliveTime     = value.dig('sessionMaxAliveTime')
        processingTime          = value.dig('processingTime')
        maxInactiveInterval     = value.dig('maxInactiveInterval')
        sessionExpireRate       = value.dig('sessionExpireRate')
        sessionAverageAliveTime = value.dig('sessionAverageAliveTime')
        rejectedSessions        = value.dig('rejectedSessions')
        processExpiresFrequency = value.dig('processExpiresFrequency')
        activeSessions          = value.dig('activeSessions')
        sessionCreateRate       = value.dig('sessionCreateRate')
        expiredSessions         = value.dig('expiredSessions')
        sessionCounter          = value.dig('sessionCounter')
        maxActive               = value.dig('maxActive')

      end

      format = '%s.%s.%s.%s.%s'

      result << {
        # PUTVAL master-17-tomcat/WFS-Manager-processing/count-time interval=15 N:4
        :key   => sprintf( format, @Host, @Service, mbean, 'processing', 'time' ),
        :value => processingTime
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'count' ),
        :value => sessionCounter
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'expired' ),
        :value => expiredSessions
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'alive_avg' ),
        :value => sessionAverageAliveTime
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'rejected' ),
        :value => rejectedSessions
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'duplicates' ),
        :value => duplicates
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'max_alive' ),
        :value => sessionMaxAliveTime
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'expire_rate' ),
        :value => sessionExpireRate
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'create_rate' ),
        :value => sessionCreateRate
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'max_active' ),
        :value => maxActive
      } << {
        :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'expire_freq' ),
        :value => processExpiresFrequency
      }

      if( maxActiveSessions.to_i != -1 )

        result << {
          :key   => sprintf( format, @Host, @Service, mbean, 'sessions', 'max_active_allowed' ),
          :value => maxActiveSessions
        }
      end

#      result.push( sprintf( format, @Host, @Service, mbean, 'processing', 'time'              , @interval, processingTime ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'count'             , @interval, sessionCounter ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expired'           , @interval, expiredSessions ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'alive_avg'         , @interval, sessionAverageAliveTime ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'rejected'          , @interval, rejectedSessions ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'duplicates'        , @interval, duplicates ) )
#
#      if( maxActiveSessions.to_i != -1 )
#        result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_active_allowed', @interval, maxActiveSessions ) )
#      end
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_alive'         , @interval, sessionMaxAliveTime ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expire_rate'       , @interval, sessionExpireRate ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'create_rate'       , @interval, sessionCreateRate ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'max_active'        , @interval, maxActive ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'sessions'  , 'expire_freq'       , @interval, processExpiresFrequency ) )

      return result
    end


    def ParseResult_Memory( data = {} )

      result = []
      mbean  = 'Memory'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      memoryTypes = ['HeapMemoryUsage', 'NonHeapMemoryUsage']

      # defaults
      init      = 0
      max       = 0
      used      = 0
      committed = 0
      percent   = 0


      def memType( m )

        case m
        when 'HeapMemoryUsage'
          type = 'heap_memory'
        else
          type = 'perm_memory'
        end

        return type

      end

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        memoryTypes.each do |m|

          init      = value.dig( m, 'init' )
          max       = value.dig( m, 'max' )
          used      = value.dig( m, 'used' )
          committed = value.dig( m, 'committed' )

          percent   = ( 100 * used / committed )

          type      = memType( m )

          result << {
            :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, type, 'init' ),
            :value => init
          } << {
            :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, type, 'max' ),
            :value => max
          } << {
            :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, type, 'used' ),
            :value => used
          } << {
            :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, type, 'used_percent' ),
            :value => percent
          } << {
            :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, type, 'committed' ),
            :value => committed
          }

#           result.push( sprintf( format, @Host, @Service, mbean, type, 'init'        , @interval, init ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'max'         , @interval, max ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'used'        , @interval, used ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent', @interval, percent ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'committed'   , @interval, committed ) )
        end
#
#       else
#
#         memoryTypes.each do |m|
#
#           type      = memType( m )
#
#           result << {
#             :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, type, 'init' ),
#             :value => init
#           } << {
#             :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, type, 'max' ),
#             :value => max
#           } << {
#             :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, type, 'used' ),
#             :value => used
#           } << {
#             :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, type, 'used_percent' ),
#             :value => percent
#           } << {
#             :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, type, 'committed' ),
#             :value => committed
#           }
#
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'init'        , @interval, init ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'max'         , @interval, max ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'used'        , @interval, used ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'used_percent', @interval, percent ) )
#           result.push( sprintf( format, @Host, @Service, mbean, type, 'committed'   , @interval, committed ) )
#         end
      end

      return result

    end


    def ParseResult_Threading( data = {} )

      result = []
      mbean  = 'Threading'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      peak   = 0
      count  = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        peak   = value.dig('PeakThreadCount')
        count  = value.dig('ThreadCount')

      end

#     PUTVAL master-17-tomcat/FEEDER_CONTENT-Threading-threading/count-peak interval=15 N:36
#     PUTVAL master-17-tomcat/FEEDER_CONTENT-Threading-threading/count-count interval=15 N:34

      result << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'peak' ),
        :value => peak
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'count' ),
        :value => count
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'threading', 'peak' , @interval, peak ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'threading', 'count', @interval, count ) )

      return result

    end


    def ParseResult_GCParNew( data = {} )

      result = []
      mbean  = 'GCParNew'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        lastGcInfo = value.dig('LastGcInfo')

        if( lastGcInfo != nil )

          duration      = lastGcInfo.dig('duration')

          #    PUTVAL master-17-tomcat/FEEDER_CONTENT-GCParNew-gc_duration/count-duration interval=15 N:2
          result << {
            :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'gc_duration', 'count' ),
            :value => duration
          }

#           result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

          # currently not needed
          # activate if you need
  #        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|
  #
  #          case gc
  #          when 'memoryUsageBeforeGc'
  #            gc_type = 'before'
  #          when 'memoryUsageAfterGc'
  #            gc_type = 'after'
  #          end
  #
  #          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|
  #
  #            if( lastGcInfo[gc][type] )
  #              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
  #              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
  #              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
  #              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil
  #
  #              percent   = ( 100 * used / committed )
  #
  #              type      = type.strip.tr( ' ', '_' ).downcase
  #
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'init'        , @interval, init ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'committed'   , @interval, committed ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'max'         , @interval, max ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used'        , @interval, used ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_parnew_%s_%s', gc_type, type ), 'used_percent', @interval, percent ) )
  #            end
  #         end
  #        end

        end
      end

      return result

    end


    def ParseResult_GCConcurrentMarkSweep( data = {} )

      result = []
      mbean  = 'GCConcurrentMarkSweep'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        lastGcInfo = value.dig('LastGcInfo')

        if( lastGcInfo != nil )

          duration      = lastGcInfo.dig('duration')

          #    PUTVAL master-17-tomcat/FEEDER_CONTENT-GCParNew-gc_duration/count-duration interval=15 N:2
          result << {
            :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'gc_duration', 'count' ),
            :value => duration
          }

#           result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_%s', 'duration' ), 'duration'     , @interval, duration ) )

          # currently not needed
          # activate if you need
  #        ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|
  #
  #          case gc
  #          when 'memoryUsageBeforeGc'
  #            gc_type = 'before'
  #          when 'memoryUsageAfterGc'
  #            gc_type = 'after'
  #          end
  #
  #          ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|
  #
  #            if( lastGcInfo[gc][type] )
  #              init      = lastGcInfo[gc][type]['init']      ? lastGcInfo[gc][type]['init']      : nil
  #              committed = lastGcInfo[gc][type]['committed'] ? lastGcInfo[gc][type]['committed'] : nil
  #              max       = lastGcInfo[gc][type]['max']       ? lastGcInfo[gc][type]['max']       : nil
  #              used      = lastGcInfo[gc][type]['used']      ? lastGcInfo[gc][type]['used']      : nil
  #
  #              type      = type.strip.tr( ' ', '_' ).downcase
  #
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'init'     , @interval, init ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'committed', @interval, committed ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'max'      , @interval, max ) )
  #              result.push( sprintf( format, @Host, @Service, mbean, sprintf( 'gc_markwseep_%s_%s', gc_type, type ), 'used'     , @interval, used ) )
  #            end
  #          end
  #        end

        end
      end

      return result

    end


    def ParseResult_ClassLoading( data = {} )

      result = []
      mbean  = 'ClassLoading'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      loaded      = 0
      totalLoaded = 0
      unloaded    = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #       value = value.values.first

        loaded      = value.dig('LoadedClassCount')
        totalLoaded = value.dig('TotalLoadedClassCount')
        unloaded    = value.dig('UnloadedClassCount')

      end

#     PUTVAL master-17-tomcat/FEEDER_CONTENT-ClassLoading-class_loading/count-loaded interval=15 N:9197
#     PUTVAL master-17-tomcat/FEEDER_CONTENT-ClassLoading-class_loading/count-total interval=15 N:9254
#     PUTVAL master-17-tomcat/FEEDER_CONTENT-ClassLoading-class_loading/count-unloaded interval=15 N:57

      result << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'loaded' ),
        :value => loaded
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'total' ),
        :value => totalLoaded
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'unloaded' ),
        :value => unloaded
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'loaded'  , @interval, loaded ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'total'   , @interval, totalLoaded ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'class_loading', 'unloaded', @interval, unloaded ) )

      return result

    end


    def ParseResult_ThreadPool( data = {} )

      # was für komische
      # müssen wir klären

    end


  end

end
