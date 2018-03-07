
module CarbonData

  module ContentServer


    def contentserver_query_pool( data = {} )

      result    = []
      mbean     = 'QueryPool'
      value     = data.dig('value')

      # defaults
      executors_running = 0
      executors_idle    = 0
      queries_max       = 0
      queries_waiting   = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        executors_running = value.dig('RunningExecutors')
        executors_idle    = value.dig('IdleExecutors')
        queries_max       = value.dig('MaxQueries')
        queries_waiting   = value.dig('WaitingQueries')
      end

      result << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'executors', 'running' ),
        value: executors_running
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'executors', 'idle' ),
        value: executors_idle
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'queries', 'max' ),
        value: queries_max
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'queries', 'waiting' ),
        value: queries_waiting
      }

      result
    end


    def contentserver_connection_pool( data = {} )

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
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'open' ),
        value: open
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'max' ),
        value: max
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'idle' ),
        value: idle
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'busy' ),
        value: busy
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'connections', 'min' ),
        value: min
      }

      result
    end


    def contentserver_server( data = {} )

      result    = []
      mbean     = 'Server'
      value     = data.dig('value')

      # defaults
      cache_hits                 = 0
      cache_evicts               = 0
      cache_entries              = 0
      cache_interval             = 0
      cache_size                 = 0
      repository_sequence_number = nil
      connection_count           = 0
      #
      #  0: offline
      #  1: online
      # 11: administration
      runlevel                   = 0
      #
      # 0: stopped
      # 1: starting
      # 2: initializing
      # 3: running
      # 4: failed
      runlevel_numeric           = 0
      uptime                     = nil
      service_infos              = nil
      license_valid_from         = nil
      license_valid_until_soft   = nil
      license_valid_until_hard   = nil

      # RLS Specific
      connection_up              = false
      controller_state           = nil
      incoming_count             = 0
      enabled                    = false
      pipeline_up                = false
      uncompleted_count          = 0
      completed_count            = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        # identical Data from MLS & RLS
        cache_hits                 = value.dig('ResourceCacheHits')
        cache_evicts               = value.dig('ResourceCacheEvicts')
        cache_entries              = value.dig('ResourceCacheEntries')
        cache_interval             = value.dig('ResourceCacheInterval')
        cache_size                 = value.dig('ResourceCacheSize')
        repository_sequence_number = value.dig('RepositorySequenceNumber')
        connection_count           = value.dig('ConnectionCount')
        runlevel                   = value.dig('RunLevel')
        runlevel_numeric           = value.dig('RunLevelNumeric')
        uptime                     = value.dig('Uptime')
        service_infos              = value.dig('ServiceInfos')
        license_valid_from         = value.dig('LicenseValidFrom')
        license_valid_until_soft   = value.dig('LicenseValidUntilSoft')
        license_valid_until_hard   = value.dig('LicenseValidUntilHard')

        # Data from RLS
        if( @normalized_service_name == 'RLS' )

          incoming_count, replicator_result = replicator_data()

          result << replicator_result if( replicator_result != nil && replicator_result.count != 0 )

          mls_sequence_number, mls_sequence_result = mls_sequence_number( incoming_count )

          result << mls_sequence_result if( mls_sequence_result != nil && mls_sequence_result.count != 0 )
        end

        # in maintenance mode the Server mbean is not available
        runlevel = case runlevel.downcase
          when 'offline'
            0
          when 'online'
            1
          when 'administration'
            11
          else
            0
        end

        if( service_infos != nil )

#           format = 'PUTVAL %s/%s-%s-%s-%s/count-%s interval=%s N:%s'

          service_infos.each do |s,v|

            enabled = v.dig('enabled') || false # ] ? v['enabled'] : false

            if( enabled == true )

              named          = v.dig('named')         || 0
              namedMax       = v.dig('maxnamed')      || 0
              namedDiff      = namedMax - named
              concurrent     = v.dig('concurrent')    || 0
              concurrentMax  = v.dig('maxconcurrent') || 0
              concurrentDiff = concurrentMax - concurrent

              result << {
                key: format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named' ),
                value: named
              } << {
                key: format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named', 'max' ),
                value: namedMax
              } << {
                key: format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'named', 'diff' ),
                value: namedDiff
              } << {
                key: format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent' ),
                value: concurrent
              } << {
                key: format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent', 'max' ),
                value: concurrentMax
              } << {
                key: format( '%s.%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ServiceInfo', s, 'concurrent', 'diff' ),
                value: concurrentDiff
              }
            end
          end
        end

        if( license_valid_from != nil || license_valid_until_soft != nil || license_valid_until_hard != nil )

          t      = Date.parse( Time.now().to_s )
          today  = Time.new( t.year, t.month, t.day )

          unless( license_valid_from.nil? )
            result << {
              key: format( '%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'from', 'raw' ),
              value: license_valid_from / 1000
            }
          end

          result << license_valid( license_valid_until_soft, mbean, 'soft' ) unless( license_valid_until_soft.nil? )
          result << license_valid( license_valid_until_hard, mbean, 'hard' ) unless( license_valid_until_hard.nil? )
        end

      end

      result << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'hits' ),
        value: cache_hits
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'evicts' ),
        value: cache_evicts
      }  << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'entries' ),
        value: cache_entries
      }  << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'interval' ),
        value: cache_interval
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'ResourceCache', 'size' ),
        value: cache_size
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'Repository', 'SequenceNumber' ),
        value: repository_sequence_number
      }  << {
        key: format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'connection' ),
        value: connection_count
      }  << {
        key: format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'uptime' ),
        value: uptime
      }  << {
        key: format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'runlevel' ),
        value: runlevel
      }  << {
        key: format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'runlevel_numeric' ),
        value: runlevel_numeric
      }

      result
    end


    def contentserver_statistics_job_result( data = {} )

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
        key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'failed' ),
        value: failed
      } << {
        key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'successful' ),
        value: successful
      } << {
        key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'unrecoverable' ),
        value: unrecoverable
      }

      result
    end


    def contentserver_statistics_resource_cache( data = {} )

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
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'size' ),
        value: size
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'removed' ),
        value: removed
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'faults' ),
        value: faults
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'misses' ),
        value: misses
      } << {
        key: format( '%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'hits' ),
        value: hits
      }

      result
    end


    def contentserver_statistics_blob_store_methods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentserver_statistics_resource( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentserver_statistics_text_store_methods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentserver_statistics_publisher_methods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def contentserver_statistics_blob_store_methods( data = {} )

      # was für komische Werte kommen da aus JMX raus?
      # müssen wir klären

    end


    private
    def replicator_data()

      result                  = []
      completed_sequence_number = 0

      replicator_data = @mbean.bean( @Server, @service_name, 'Replicator' )

      if( replicator_data == false )

        logger.error( format( 'No mbean \'Replicator\' for Service %s found!', @service_name ) )

        [completed_sequence_number, result]
      else

        replicator_status = replicator_data.dig('status') || 505
        replicator_value  = replicator_data.dig('value')

        if( replicator_status == 200 && replicator_value != nil )

          replicator_value           = replicator_value.values.first

          connection_up             = replicator_value.dig('ConnectionUp')                  || false # why and what?
          controller_state          = replicator_value.dig('ControllerState')                        #  why and what?
          completed_sequence_number = replicator_value.dig('LatestCompletedSequenceNumber') || 0
          enabled                   = replicator_value.dig('Enabled')                       || false
          pipeline_up               = replicator_value.dig('PipelineUp')                    || false #  why and what?
          uncompleted_count         = replicator_value.dig('UncompletedCount')              || 0
          completed_count           = replicator_value.dig('CompletedCount')                || 0

          # TODO
          #  why and what?
          controller_state.downcase!

          result << {
            key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'CompletedSequenceNumber' ),
            value: completed_sequence_number
          } << {
            key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'uncompleted' ),
            value: uncompleted_count
          } << {
            key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'Replicator', 'completed' ),
            value: completed_count
          }
        end

        [completed_sequence_number, result]
      end
    end


    def mls_sequence_number( rlsSequenceNumber )

      result            = []
      mls_sequence_number = 0

      replicator_data = @mbean.bean( @Server, @service_name, 'Replicator' )

      if( replicator_data == false )
        logger.error( format( 'No mbean \'Replicator\' for Service %s found!', @service_name ) )
        logger.debug( "#{@Server}, #{@service_name}, 'Replicator'" )
#        return [mls_sequence_number, result]
      else

        replicator_status = replicator_data.dig('status') || 505
        replicator_value  = replicator_data.dig('value')

        if( replicator_status == 200 && replicator_value != nil )

          replicator_value   = replicator_value.values.first

#           logger.debug( "replicator_value : #{replicator_value}" )

          master_live_server  = replicator_value.dig('MasterLiveServer','host')

#           logger.debug( "master_live_server: #{master_live_server}" )

          master_live_server = @Server if( master_live_server.nil? )

          repository_data    = @mbean.bean( master_live_server, 'master-live-server', 'Server' )

          if( repository_data == false )
            logger.error( 'No mbean \'Server\' for Service \'master-live-server\' found!' )
#             logger.debug( "#{master_live_server}, 'master-live-server', 'Server'" )
#             return [mls_sequence_number, result]
          else

            repository_status = repository_data.dig('status') || 505
            repository_value  = repository_data.dig('value')

            if( repository_status == 200 && repository_value != nil )

              repository_value = repository_value.values.first
#               logger.debug( repository_value )
              mls_sequence_number  = repository_value.dig('RepositorySequenceNumber')

              diff_sequence_number = mls_sequence_number.to_i - rlsSequenceNumber.to_i

              result << {
                key: format( '%s.%s.%s.%s', @identifier, @normalized_service_name, 'SequenceNumber', 'diffToMLS' ),
                value: diff_sequence_number
              }
            end
#             [mls_sequence_number, result]
          end
        end
      end

      [mls_sequence_number, result]
    end


    #
    #
    def license_valid( license_valid_until, mbean, type )

      result = []
      t      = Date.parse( Time.now().to_s )
      today  = Time.new( t.year, t.month, t.day )

      x = time_parser( today, Time.at( license_valid_until / 1000 ) )
      month = x.dig(:months)
      week  = x.dig(:weeks)
      days  = x.dig(:days)

      result << {
        key: format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', type, 'raw' ),
        value: license_valid_until / 1000
      } << {
        key: format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', type, 'month' ),
        value: month
      }  << {
        key: format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', type, 'weeks' ),
        value: week
      }  << {
        key: format( '%s.%s.%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'license', 'until', type, 'days' ),
        value: days
      }

    end

  end

end
