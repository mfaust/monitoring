
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
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'executors', 'running' ),
        :value => executorsRunning
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'executors', 'idle' ),
        :value => executorsIdle
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'queries', 'max' ),
        :value => queriesMax
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'queries', 'waiting' ),
        :value => queriesWaiting
      }

      return result

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
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'connections', 'open' ),
        :value => open
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'connections', 'max' ),
        :value => max
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'connections', 'idle' ),
        :value => idle
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'connections', 'busy' ),
        :value => busy
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'connections', 'min' ),
        :value => min
      }

      return result

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

        replicatorData = @mbean.bean( @Server, @serviceName, 'Replicator' )

        if( replicatorData == false )

          logger.error( sprintf( 'No mbean \'Replicator\' for Service %s found!', @serviceName ) )

          return completedSequenceNumber, result

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
              :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, 'Replicator', 'completedSequenceNumber' ),
              :value => completedSequenceNumber
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, 'Replicator', 'uncompleted' ),
              :value => uncompletedCount
            } << {
              :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, 'Replicator', 'completed' ),
              :value => completedCount
            }
          end

          return completedSequenceNumber, result
        end
      end


      def mlsSequenceNumber( rlsSequenceNumber )

#         logger.debug( "mlsSequenceNumber( #{rlsSequenceNumber} )" )

        result            = []
        mlsSequenceNumber = 0

#         logger.debug( @identifier )
#         logger.debug( @serviceName )

        replicatorData = @mbean.bean( @Server, @serviceName, 'Replicator' )

        if( replicatorData == false )

          logger.error( sprintf( 'No mbean \'Replicator\' for Service %s found!', @serviceName ) )
          logger.debug( "#{@Server}, #{@serviceName}, 'Replicator'" )

          [mlsSequenceNumber, result]
        else

          replicatorStatus = replicatorData.dig('status') || 505
          replicatorValue  = replicatorData.dig('value')

          if( replicatorStatus == 200 && replicatorValue != nil )

            replicatorValue   = replicatorValue.values.first

            logger.debug( replicatorValue )

            masterLiveServer  = replicatorValue.dig('MasterLiveServer','host')

            unless( masterLiveServer.nil? )
              masterLiveServer = @Server
            end

            # {:host=>"blueprint-box", :pre=>"result", :service=>"master-live-server"}
            repositoryData    = @mbean.bean( masterLiveServer, 'master-live-server', 'Server' )

            if( repositoryData == false )

              logger.error( 'No mbean \'Server\' for Service \'master-live-server\' found!' )
              logger.debug( "#{masterLiveServer}, 'master-live-server', 'Server'" )

              [mlsSequenceNumber, result]
            else

              repositoryStatus = repositoryData.dig('status') || 505
              repositoryValue  = repositoryData.dig('value')

              if( repositoryStatus == 200 && repositoryValue != nil )

                repositoryValue         = repositoryValue.values.first

#                 logger.debug( repositoryValue )

                mlsSequenceNumber  = repositoryValue.dig('RepositorySequenceNumber')

                diffSequenceNumber = mlsSequenceNumber.to_i - rlsSequenceNumber.to_i

                result << {
                  :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, 'SequenceNumber', 'diffToMLS' ),
                  :value => diffSequenceNumber
                }

              end

              [mlsSequenceNumber, result]
            end
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

          if( replicatorResult != nil && replicatorResult.count != 0 )
            result << replicatorResult
          end

          mlsSequenceNumber, mlsSequenceResult = mlsSequenceNumber( incomingCount )

          if( mlsSequenceResult != nil && mlsSequenceResult.count != 0 )
            result << mlsSequenceResult
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
                :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'ServiceInfo', s, 'named' ),
                :value => named
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ServiceInfo', s, 'named', 'max' ),
                :value => namedMax
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ServiceInfo', s, 'named', 'diff' ),
                :value => namedDiff
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'ServiceInfo', s, 'concurrent' ),
                :value => concurrent
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ServiceInfo', s, 'concurrent', 'max' ),
                :value => concurrentMax
              } << {
                :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ServiceInfo', s, 'concurrent', 'diff' ),
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
              :key   => sprintf( '%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'from', 'raw' ),
              :value => licenseValidFrom / 1000
            }

          end


          if( licenseValidUntilSoft != nil )

            x                   = timeParser( today, Time.at( licenseValidUntilSoft / 1000 ) )
            validUntilSoftMonth = x.dig(:months)
            validUntilSoftWeek  = x.dig(:weeks)
            validUntilSoftDays  = x.dig(:days)

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'soft', 'raw' ),
              :value => licenseValidUntilSoft / 1000
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'soft', 'month' ),
              :value => validUntilSoftMonth
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'soft', 'weeks' ),
              :value => validUntilSoftWeek
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'soft', 'days' ),
              :value => validUntilSoftDays
            }

          end

          if( licenseValidUntilHard != nil )

            x                   = timeParser( today, Time.at( licenseValidUntilHard / 1000 ) )
            validUntilHardMonth = x.dig(:months)
            validUntilHardWeek  = x.dig(:weeks)
            validUntilHardDays  = x.dig(:days)

            result << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'hard', 'raw' ),
              :value => licenseValidUntilHard / 1000
            } << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'hard', 'month' ),
              :value => validUntilHardMonth
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'hard', 'weeks' ),
              :value => validUntilHardWeek
            }  << {
              :key   => sprintf( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'license', 'until', 'hard', 'days' ),
              :value => validUntilHardDays
            }

          end
        end

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ResourceCache', 'hits' ),
        :value => cacheHits
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ResourceCache', 'evicts' ),
        :value => cacheEvicts
      }  << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ResourceCache', 'entries' ),
        :value => cacheEntries
      }  << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ResourceCache', 'interval' ),
        :value => cacheInterval
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'ResourceCache', 'size' ),
        :value => cacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'Repository', 'SequenceNumber' ),
        :value => reqSeqNumber
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, mbean, 'connection' ),
        :value => connectionCount
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, mbean, 'uptime' ),
        :value => uptime
      }  << {
        :key   => sprintf( '%s.%s.%s.%s'   , @identifier, @Service, mbean, 'runlevel' ),
        :value => runlevel
      }

      return result

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
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'failed' ),
        :value => failed
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'successful' ),
        :value => successful
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'unrecoverable' ),
        :value => unrecoverable
      }

      return result

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
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'cache', 'size' ),
        :value => size
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'cache', 'removed' ),
        :value => removed
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'cache', 'faults' ),
        :value => faults
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'cache', 'misses' ),
        :value => misses
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'cache', 'hits' ),
        :value => hits
      }

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
