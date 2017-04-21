
module CarbonData

  module ContentServer


    def contentServerQueryPool( data = {} )

      result    = []
      mbean     = 'QueryPool'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      executorsRunning = 0
      executorsIdle    = 0
      queriesMax       = 0
      queriesWaiting   = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        executorsRunning = value.dig('RunningExecutors')
        executorsIdle    = value.dig('IdleExecutors')
        queriesMax       = value.dig('MaxQueries')
        queriesWaiting   = value.dig('WaitingQueries')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'executors', 'running' ),
        :value => executorsRunning
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'executors', 'idle' ),
        :value => executorsIdle
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'queries', 'max' ),
        :value => queriesMax
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'queries', 'waiting' ),
        :value => queriesWaiting
      }

#      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_running', @interval, executorsRunning ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_idle'   , @interval, executorsIdle ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_max'      , @interval, queriesMax ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_waiting'  , @interval, queriesWaiting ) )
#
      return result

    end


    def contentServerConnectionPool( data = {} )

      result    = []
      mbean     = 'ConnectionPool'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      open   = 0
      max    = 0
      idle   = 0
      busy   = 0
      min    = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        open   = value.dig('OpenConnections')
        max    = value.dig('MaxConnections')
        idle   = value.dig('IdleConnections')
        busy   = value.dig('BusyConnections')
        min    = value.dig('MinConnections')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'connections', 'open' ),
        :value => open
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'connections', 'max' ),
        :value => max
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'connections', 'idle' ),
        :value => idle
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'connections', 'busy' ),
        :value => busy
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'connections', 'min' ),
        :value => min
      }

#      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'open', @interval, open ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'max' , @interval, max ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'idle', @interval, idle ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'busy', @interval, busy ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'min' , @interval, min ) )

      return result

    end


    def contentServerServer( data = {} )

      result    = []
      mbean     = 'Server'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      cacheHits             = 0
      cacheEvicts           = 0
      cacheEntries          = 0
      cacheInterval         = 0
      cacheSize             = 0
      reqSeqNumber          = nil
      connectionCount       = 0
      runlevel              = nil
      uptime                = nil
      serviceInfos          = nil
      licenseValidFrom      = nil
      licenseValidUntilSoft = nil
      licenseValidUntilHard = nil

      # RLS Specific
      connectionUp          = false
      controllerState       = nil
      incomingCount         = 0
      enabled               = false
      pipelineUp            = false
      uncompletedCount      = 0
      completedCount        = 0

      def replicatorData()

        result       = []

        replicatorData = @mbean.bean( @Host, @serviceName, 'Replicator' )



        if( replicatorData == false )

          logger.error( sprintf( 'No mbean \'Replicator\' for Service %s found!', @serviceName ) )

          return completedSequenceNumber, result

#          return {
#            :completedSequenceNumber => 0,
#            :result                  => result
#          }
        else

          replicatorStatus = replicatorData.dig('status') || 505
          replicatorValue  = replicatorData.dig('value')

          if( replicatorStatus == 200 && replicatorValue != nil )

            replicatorValue         = replicatorValue.values.first

            connectionUp            = replicatorValue.dig('ConnectionUp') || false
            controllerState         = replicatorValue.dig('ControllerState')
            completedSequenceNumber = replicatorValue.dig('LatestCompletedSequenceNumber') || 0
            enabled                 = replicatorValue.dig('Enabled') || false
            pipelineUp              = replicatorValue.dig('PipelineUp') || false
            uncompletedCount        = replicatorValue.dig('UncompletedCount') || 0
            completedCount          = replicatorValue.dig('CompletedCount') || 0

            controllerState.downcase!

            result << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'Replicator', 'completedSequenceNumber' ),
              :value => completedSequenceNumber
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'Replicator', 'uncompleted' ),
              :value => uncompletedCount
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, 'Replicator', 'completed' ),
              :value => completedCount
            }

#             format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'

#   #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'connection'              ,'up'      , @interval, connectionUp ) )
#   #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'controller'              ,'state'   , @interval, controllerState ) )
#             result.push( sprintf( format, @Host, @Service, 'Replicator', 'completedSequenceNumber' ,'count'   , @interval, completedSequenceNumber ) )
#   #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'pipeline'                ,'up'      , @interval, pipelineUp ) )
#             result.push( sprintf( format, @Host, @Service, 'Replicator', 'uncompleted'             ,'count'   , @interval, uncompletedCount ) )
#             result.push( sprintf( format, @Host, @Service, 'Replicator', 'completed'               ,'count'   , @interval, completedCount ) )
#   #           result.push( sprintf( 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s', @Host, @Service, 'Replicator', 'enabled', @interval, enabled ) )

            return completedSequenceNumber, result

#            return {
#              :completedSequenceNumber => completedSequenceNumber,
#              :result                  => result
#            }

          end
        end
      end


      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        # identical Data from MLS & RLS
        cacheHits             = value.dig('ResourceCacheHits')
        cacheEvicts           = value.dig('ResourceCacheEvicts')
        cacheEntries          = value.dig('ResourceCacheEntries')
        cacheInterval         = value.dig('ResourceCacheInterval')
        cacheSize             = value.dig('ResourceCacheSize')
        reqSeqNumber          = value.dig('RepositorySequenceNumber')
        connectionCount       = value.dig('ConnectionCount')
        runlevel              = value.dig('RunLevel')
        uptime                = value.dig('Uptime')
        serviceInfos          = value.dig('ServiceInfos')
        licenseValidFrom      = value.dig('LicenseValidFrom')
        licenseValidUntilSoft = value.dig('LicenseValidUntilSoft')
        licenseValidUntilHard = value.dig('LicenseValidUntilHard')

        # Data from RLS
        if( @Service == 'RLS' )

          incomingCount, replicatorResult = replicatorData()

#          replicatorData        = replicatorData()
#
#          incomingCount         = replicatorData.dig(:completedSequenceNumber) || 0
#          replicatorResult      = replicatorData.dig(:result)

          if( replicatorResult != nil && replicatorResult.count != 0 )
            result << replicatorResult
          end
        end

        # in maintenance mode the Server mbean is not available
        case runlevel.downcase
          when 'offline'
            runlevel = 0
          when 'online'
            runlevel = 1
          when 'administration'
            runlevel = 11
        else
          runlevel = 0
        end

        if( serviceInfos != nil )

          format = 'PUTVAL %s/%s-%s-%s-%s/count-%s interval=%s N:%s'

          serviceInfos.each do |s,v|

            enabled = v['enabled'] ? v['enabled'] : false

            if( enabled == true )

              named          = v.dig('named')         || 0
              namedMax       = v.dig('maxnamed')      || 0
              namedDiff      = namedMax - named
              concurrent     = v.dig('concurrent')    || 0
              concurrentMax  = v.dig('maxconcurrent') || 0
              concurrentDiff = concurrentMax - concurrent

              result << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ServiceInfo', s, 'named' ),
                :value => named
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'ServiceInfo', s, 'named', 'max' ),
                :value => namedMax
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'ServiceInfo', s, 'named', 'diff' ),
                :value => namedDiff
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ServiceInfo', s, 'concurrent' ),
                :value => concurrent
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'ServiceInfo', s, 'concurrent', 'max' ),
                :value => concurrentMax
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'ServiceInfo', s, 'concurrent', 'diff' ),
                :value => concurrentDiff
              }

#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named'          , @interval, named ) )
#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_max'      , @interval, namedMax ) )
#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_diff'     , @interval, namedDiff ) )
#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent'     , @interval, concurrent ) )
#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_max' , @interval, concurrentMax ) )
#               result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_diff', @interval, concurrentDiff ) )

            end
          end
        end

        if( licenseValidFrom != nil || licenseValidUntilSoft != nil || licenseValidUntilHard != nil )

#           format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
          t      = Date.parse( Time.now().to_s )
          today  = Time.new( t.year, t.month, t.day )

          if( licenseValidFrom != nil )

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'from', 'raw' ),
              :value => licenseValidFrom / 1000
            }

#             result.push( sprintf( format, @Host, @Service, mbean, 'license_from', 'raw'      , @interval, licenseValidFrom / 1000 ) )

          end


          if( licenseValidUntilSoft != nil )

            x                   = self.timeParser( today, Time.at( licenseValidUntilSoft / 1000 ) )
            validUntilSoftMonth = x.dig(:months)
            validUntilSoftWeek  = x.dig(:weeks)
            validUntilSoftDays  = x.dig(:days)

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'soft', 'raw' ),
              :value => licenseValidUntilSoft / 1000
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'soft', 'month' ),
              :value => validUntilSoftMonth
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'soft', 'weeks' ),
              :value => validUntilSoftWeek
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'soft', 'days' ),
              :value => validUntilSoftDays
            }

#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'raw'    , @interval, licenseValidUntilSoft / 1000 ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'months' , @interval, validUntilSoftMonth ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'weeks'  , @interval, validUntilSoftWeek ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'days'   , @interval, validUntilSoftDays ) )

          end

          if( licenseValidUntilHard != nil )

            x                   = self.timeParser( today, Time.at( licenseValidUntilHard / 1000 ) )
            validUntilHardMonth = x.dig(:months)
            validUntilHardWeek  = x.dig(:weeks)
            validUntilHardDays  = x.dig(:days)

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'hard', 'raw' ),
              :value => licenseValidUntilHard / 1000
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'hard', 'month' ),
              :value => validUntilHardMonth
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'hard', 'weeks' ),
              :value => validUntilHardWeek
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'license', 'until', 'hard', 'days' ),
              :value => validUntilHardDays
            }

#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'raw'    , @interval, licenseValidUntilHard / 1000 ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'months' , @interval, validUntilHardMonth ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'weeks'  , @interval, validUntilHardWeek ) )
#             result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'days'   , @interval, validUntilHardDays ) )
          end
        end

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ResourceCache', 'hits' ),
        :value => cacheHits
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ResourceCache', 'evicts' ),
        :value => cacheEvicts
      }  << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ResourceCache', 'entries' ),
        :value => cacheEntries
      }  << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ResourceCache', 'interval' ),
        :value => cacheInterval
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'ResourceCache', 'size' ),
        :value => cacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'Repository', 'SequenceNumber' ),
        :value => reqSeqNumber
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'connection' ),
        :value => connectionCount
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'uptime' ),
        :value => uptime
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'runlevel' ),
        :value => runlevel
      }


#       format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
#
#       result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'hits'            , @interval, cacheHits ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'evicts'          , @interval, cacheEvicts ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'entries'         , @interval, cacheEntries ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'interval'        , @interval, cacheInterval ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'size'            , @interval, cacheSize ) )
#
#       result.push( sprintf( format, @Host, @Service, mbean, 'Repository'   , 'sequence_number' , @interval, reqSeqNumber ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'connection_count', @interval, connectionCount ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'uptime'          , @interval, uptime ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'runlevel'        , @interval, runlevel ) )

      return result

    end


    def contentServerStatisticsJobResult( data = {} )

      result    = []
      mbean     = 'StatisticsJobResult'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      failed        = 0
      successful    = 0
      unrecoverable = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        failed        = value.dig('Failed')
        successful    = value.dig('Successful')
        unrecoverable = value.dig('Unrecoverable')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'failed' ),
        :value => failed
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'successful' ),
        :value => successful
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'unrecoverable' ),
        :value => unrecoverable
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'failed'       , @interval, failed ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'successful'   , @interval, successful ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'unrecoverable', @interval, unrecoverable ) )

      return result

    end


    def contentServerStatisticsResourceCache( data = {} )

      result    = []
      mbean     = 'StatisticsResourceCache'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      size     = 0
      removed  = 0
      faults   = 0
      misses   = 0
      hits     = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        size     = value.dig('CacheSize')
        removed  = value.dig('CacheRemoved')
        faults   = value.dig('CacheFaults')
        misses   = value.dig('CacheMisses')
        hits     = value.dig('CacheHits')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'size' ),
        :value => size
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'removed' ),
        :value => removed
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'faults' ),
        :value => faults
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'misses' ),
        :value => misses
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'hits' ),
        :value => hits
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'size'   , @interval, size ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'removed', @interval, removed ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'faults' , @interval, faults ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'misses' , @interval, misses ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'hits'   , @interval, hits ) )

      return result

    end


    def contentServerStatisticsBlobStoreMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentServerStatisticsResource( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentServerStatisticsTextStoreMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentServerStatisticsPublisherMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentServerStatisticsBlobStoreMethods( data = {} )

      # was für komische Werte kommen da aus JMX raus?
      # müssen wir klären

    end

  end

end
