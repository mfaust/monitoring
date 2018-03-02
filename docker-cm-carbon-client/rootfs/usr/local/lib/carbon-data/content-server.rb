
module CarbonData

  module ContentServer


    def contentServerQueryPool( data = {} )

      result    = []
      mbean     = 'QueryPool'
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
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'executors', 'running' ),
        :value => executorsRunning
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'executors', 'idle' ),
        :value => executorsIdle
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'queries', 'max' ),
        :value => queriesMax
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'queries', 'waiting' ),
        :value => queriesWaiting
      }

      result
    end


    def contentServerConnectionPool( data = {} )

      result    = []
      mbean     = 'ConnectionPool'
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
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'open' ),
        :value => open
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'max' ),
        :value => max
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'idle' ),
        :value => idle
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'busy' ),
        :value => busy
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'min' ),
        :value => min
      }

      result
    end


    def contentServerServer( data = {} )

      result    = []
      mbean     = 'Server'
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

        result                  = []
        completedSequenceNumber = 0

        replicatorData = @mbean.bean( @Server, @service_name, 'Replicator' )

        if( replicatorData == false )

          logger.error( format( 'No mbean \'Replicator\' for Service %s found!', @service_name ) )

          [completedSequenceNumber, result]
        else

          replicatorStatus = replicatorData.dig('status') || 505
          replicatorValue  = replicatorData.dig('value')

          if( replicatorStatus == 200 && replicatorValue != nil )

            replicatorValue         = replicatorValue.values.first

            connectionUp            = replicatorValue.dig('ConnectionUp')                  || false
            controllerState         = replicatorValue.dig('ControllerState')
            completedSequenceNumber = replicatorValue.dig('LatestCompletedSequenceNumber') || 0
            enabled                 = replicatorValue.dig('Enabled')                       || false
            pipelineUp              = replicatorValue.dig('PipelineUp')                    || false
            uncompletedCount        = replicatorValue.dig('UncompletedCount')              || 0
            completedCount          = replicatorValue.dig('CompletedCount')                || 0

            controllerState.downcase!

            result << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'completedSequenceNumber' ),
              :value => completedSequenceNumber
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'uncompleted' ),
              :value => uncompletedCount
            } << {
              :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'completed' ),
              :value => completedCount
            }
          end

          [completedSequenceNumber, result]
        end
      end


      def mlsSequenceNumber( rlsSequenceNumber )

        result            = []
        mlsSequenceNumber = 0

        replicatorData = @mbean.bean( @Server, @service_name, 'Replicator' )

        if( replicatorData == false )
          logger.error( format( 'No mbean \'Replicator\' for Service %s found!', @service_name ) )
          logger.debug( "#{@Server}, #{@service_name}, 'Replicator'" )
#          return [mlsSequenceNumber, result]
        else

          replicatorStatus = replicatorData.dig('status') || 505
          replicatorValue  = replicatorData.dig('value')

          if( replicatorStatus == 200 && replicatorValue != nil )

            replicatorValue   = replicatorValue.values.first

            logger.debug( "replicatorValue : #{replicatorValue}" )

            masterLiveServer  = replicatorValue.dig('MasterLiveServer','host')

            logger.debug( "masterLiveServer: #{masterLiveServer}" )

            masterLiveServer = @Server if( masterLiveServer.nil? )

            repositoryData    = @mbean.bean( masterLiveServer, 'master-live-server', 'Server' )

            if( repositoryData == false )
              logger.error( 'No mbean \'Server\' for Service \'master-live-server\' found!' )
              logger.debug( "#{masterLiveServer}, 'master-live-server', 'Server'" )
#              return [mlsSequenceNumber, result]
            else

              repositoryStatus = repositoryData.dig('status') || 505
              repositoryValue  = repositoryData.dig('value')

              if( repositoryStatus == 200 && repositoryValue != nil )

                repositoryValue         = repositoryValue.values.first
#                 logger.debug( repositoryValue )
                mlsSequenceNumber  = repositoryValue.dig('RepositorySequenceNumber')

                diffSequenceNumber = mlsSequenceNumber.to_i - rlsSequenceNumber.to_i

                result << {
                  :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'SequenceNumber', 'diffToMLS' ),
                  :value => diffSequenceNumber
                }
              end

#              [mlsSequenceNumber, result]
            end
          end
        end

        [mlsSequenceNumber, result]
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
        if( @normalized_service_name == 'RLS' )

          incomingCount, replicatorResult = replicatorData()

          result << replicatorResult if( replicatorResult != nil && replicatorResult.count != 0 )

          mlsSequenceNumber, mlsSequenceResult = mlsSequenceNumber( incomingCount )

          result << mlsSequenceResult if( mlsSequenceResult != nil && mlsSequenceResult.count != 0 )
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

#           format = 'PUTVAL %s/%s-%s-%s-%s/count-%s interval=%s N:%s'

          serviceInfos.each do |s,v|

            enabled = v.dig('enabled') || false # ] ? v['enabled'] : false

            if( enabled == true )

              named          = v.dig('named')         || 0
              namedMax       = v.dig('maxnamed')      || 0
              namedDiff      = namedMax - named
              concurrent     = v.dig('concurrent')    || 0
              concurrentMax  = v.dig('maxconcurrent') || 0
              concurrentDiff = concurrentMax - concurrent

              result << {
                :key   => format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named' ),
                :value => named
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named', 'max' ),
                :value => namedMax
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named', 'diff' ),
                :value => namedDiff
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent' ),
                :value => concurrent
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent', 'max' ),
                :value => concurrentMax
              } << {
                :key   => format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent', 'diff' ),
                :value => concurrentDiff
              }
            end
          end
        end

        if( licenseValidFrom != nil || licenseValidUntilSoft != nil || licenseValidUntilHard != nil )

          t      = Date.parse( Time.now().to_s )
          today  = Time.new( t.year, t.month, t.day )

          if( licenseValidFrom != nil )

            result << {
              :key   => format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'from', 'raw' ),
              :value => licenseValidFrom / 1000
            }
          end


          if( licenseValidUntilSoft != nil )

            x                   = timeParser( today, Time.at( licenseValidUntilSoft / 1000 ) )
            validUntilSoftMonth = x.dig(:months)
            validUntilSoftWeek  = x.dig(:weeks)
            validUntilSoftDays  = x.dig(:days)

            result << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'soft', 'raw' ),
              :value => licenseValidUntilSoft / 1000
            } << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'soft', 'month' ),
              :value => validUntilSoftMonth
            }  << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'soft', 'weeks' ),
              :value => validUntilSoftWeek
            }  << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'soft', 'days' ),
              :value => validUntilSoftDays
            }
          end

          if( licenseValidUntilHard != nil )

            x                   = timeParser( today, Time.at( licenseValidUntilHard / 1000 ) )
            validUntilHardMonth = x.dig(:months)
            validUntilHardWeek  = x.dig(:weeks)
            validUntilHardDays  = x.dig(:days)

            result << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'hard', 'raw' ),
              :value => licenseValidUntilHard / 1000
            } << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'hard', 'month' ),
              :value => validUntilHardMonth
            }  << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'hard', 'weeks' ),
              :value => validUntilHardWeek
            }  << {
              :key   => format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', 'hard', 'days' ),
              :value => validUntilHardDays
            }
          end
        end

      end

      result << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'hits' ),
        :value => cacheHits
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'evicts' ),
        :value => cacheEvicts
      }  << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'entries' ),
        :value => cacheEntries
      }  << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'interval' ),
        :value => cacheInterval
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'size' ),
        :value => cacheSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'Repository', 'SequenceNumber' ),
        :value => reqSeqNumber
      }  << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'connection' ),
        :value => connectionCount
      }  << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'uptime' ),
        :value => uptime
      }  << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'runlevel' ),
        :value => runlevel
      }

      result
    end


    def contentServerStatisticsJobResult( data = {} )

      result    = []
      mbean     = 'StatisticsJobResult'
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
        :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'failed' ),
        :value => failed
      } << {
        :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'successful' ),
        :value => successful
      } << {
        :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'unrecoverable' ),
        :value => unrecoverable
      }

      result
    end


    def contentServerStatisticsResourceCache( data = {} )

      result    = []
      mbean     = 'StatisticsResourceCache'
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
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'size' ),
        :value => size
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'removed' ),
        :value => removed
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'faults' ),
        :value => faults
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'misses' ),
        :value => misses
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'hits' ),
        :value => hits
      }

      result
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
