
module CarbonData

  module Tomcat

    def tomcatRuntime( data = {} )

      result    = []
      mbean     = 'Runtime'
      value     = data.dig('value')

      # defaults
      uptime  = 0
      start   = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

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

      return result
    end


    def tomcatOperatingSystem( data = {} )

      result    = []
      mbean     = 'OperatingSystem'
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

        logger.debug( JSON.pretty_generate( value ) )

  #       value = value.values.first
      end

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


    def tomcatManager( data = {} )

      result    = []
      mbean     = 'Manager'
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

      result << {
        # PUTVAL master-17-tomcat/WFS-Manager-processing/count-time interval=15 N:4
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'processing', 'time' ),
        :value => processingTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'count' ),
        :value => sessionCounter
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'expired' ),
        :value => expiredSessions
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'alive_avg' ),
        :value => sessionAverageAliveTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'rejected' ),
        :value => rejectedSessions
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'duplicates' ),
        :value => duplicates
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'max_alive' ),
        :value => sessionMaxAliveTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'expire_rate' ),
        :value => sessionExpireRate
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'create_rate' ),
        :value => sessionCreateRate
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'max_active' ),
        :value => maxActive
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'expire_freq' ),
        :value => processExpiresFrequency
      }

      if( maxActiveSessions.to_i != -1 )

        result << {
          :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'sessions', 'max_active_allowed' ),
          :value => maxActiveSessions
        }
      end

      return result
    end


    def tomcatMemoryUsage( data = {} )

      result    = []
      mbean     = 'Memory'
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

        end

      end

      return result

    end


    def tomcatThreading( data = {} )

      result    = []
      mbean     = 'Threading'
      value     = data.dig('value')

      # defaults
      peak   = 0
      count  = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        peak   = value.dig('PeakThreadCount')
        count  = value.dig('ThreadCount')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'peak' ),
        :value => peak
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'count' ),
        :value => count
      }

      return result

    end


    def tomcatGCMemoryUsage( mbean, data )

      value     = data.dig('value')
      result    = []

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        lastGcInfo = value.dig('LastGcInfo')

        if( lastGcInfo != nil )

          threadCount   = lastGcInfo.dig('GcThreadCount')   # The number of GC threads.
          duration      = lastGcInfo.dig('duration')        # The elapsed time of this GC. (milliseconds)

          mbean.gsub!( 'GC', 'GarbageCollector.' )

          result << {
            :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'threads', 'count' ),
            :value => threadCount
          } << {
            :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'duration', 'time' ),
            :value => duration
          }

          # currently not needed
          # activate if you need
          #
          # memoryUsageAfterGc  - The memory usage of all memory pools at the end of this GC.
          # memoryUsageBeforeGc - The memory usage of all memory pools at the beginning of this GC.
          #
#          ['memoryUsageBeforeGc', 'memoryUsageAfterGc'].each do |gc|
#
#            case gc
#            when 'memoryUsageBeforeGc'
#              gcType = 'before'
#            when 'memoryUsageAfterGc'
#              gcType = 'after'
#            end
#
#            ['Par Survivor Space', 'CMS Perm Gen', 'Code Cache', 'Par Eden Space', 'CMS Old Gen', 'Compressed Class Space', 'Metaspace' ].each do |type|
#
#              lastGcInfoType = lastGcInfo.dig( gc, type )
#
#              if( lastGcInfoType != nil )
#
#                init      = lastGcInfoType.dig( 'init' )
#                committed = lastGcInfoType.dig( 'committed' )
#                max       = lastGcInfoType.dig( 'max' )
#                used      = lastGcInfoType.dig( 'used' )
#
#                type      = type.strip.tr( ' ', '_' ).downcase
#
#                result << {
#                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'duration', gcType, type, 'init' ),
#                  :value => init
#                } << {
#                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'duration', gcType, type, 'committed' ),
#                  :value => committed
#                } << {
#                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'duration', gcType, type, 'max' ),
#                  :value => max
#                } << {
#                  :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'duration', gcType, type, 'used' ),
#                  :value => used
#                }
#
#              end
#            end
#          end

        end
      end

      return result

    end


    def tomcatGCParNew( data = {} )

      return self.tomcatGCMemoryUsage( 'GCParNew', data )

    end


    def tomcatGCConcurrentMarkSweep( data = {} )

      return self.tomcatGCMemoryUsage( 'GCConcurrentMarkSweep', data )

    end


    def tomcatClassLoading( data = {} )

      result    = []
      mbean     = 'ClassLoading'
      value     = data.dig('value')

      # defaults
      loaded      = 0
      totalLoaded = 0
      unloaded    = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        loaded      = value.dig('LoadedClassCount')
        totalLoaded = value.dig('TotalLoadedClassCount')
        unloaded    = value.dig('UnloadedClassCount')

      end

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

      return result

    end


    def tomcatThreadPool( data = {} )

      # was für komische
      # müssen wir klären

    end


  end

end
