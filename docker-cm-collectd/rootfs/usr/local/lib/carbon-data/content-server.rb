
module CarbonData

  module ContentServer



    def ParseResult_QueryPool( data = {} )

      result = []
      mbean  = 'QueryPool'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      executorsRunning = 0
      executorsIdle    = 0
      queriesMax       = 0
      queriesWaiting   = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        executorsRunning = value['RunningExecutors'] ? value['RunningExecutors'] : nil
        executorsIdle    = value['IdleExecutors']    ? value['IdleExecutors']    : nil
        queriesMax       = value['MaxQueries']       ? value['MaxQueries']       : nil
        queriesWaiting   = value['WaitingQueries']   ? value['WaitingQueries']   : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_running', @interval, executorsRunning ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'executors_idle'   , @interval, executorsIdle ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_max'      , @interval, queriesMax ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'query_pool', 'queries_waiting'  , @interval, queriesWaiting ) )

      return result

    end

    def ParseResult_StatisticsBlobStoreMethods( data = {} )

      # was für komische Werte kommen da aus JMX raus?
      # müssen wir klären

    end


    def ParseResult_StatisticsJobResult( data = {} )

      result = []
      mbean  = 'StatisticsJobResult'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      failed        = 0
      successful    = 0
      unrecoverable = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        failed        = value['Failed']        ? value['Failed']        : nil
        successful    = value['Successful']    ? value['Successful']    : nil
        unrecoverable = value['Unrecoverable'] ? value['Unrecoverable'] : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'failed'       , @interval, failed ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'successful'   , @interval, successful ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_jobresult', 'unrecoverable', @interval, unrecoverable ) )

      return result

    end


    def ParseResult_StatisticsResourceCache( data = {} )

      result = []
      mbean  = 'StatisticsResourceCache'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      size     = 0
      removed  = 0
      faults   = 0
      misses   = 0
      hits     = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        size     = value['CacheSize']     ? value['CacheSize']     : nil
        removed  = value['CacheRemoved']  ? value['CacheRemoved']  : nil
        faults   = value['CacheFaults']   ? value['CacheFaults']   : nil
        misses   = value['CacheMisses']   ? value['CacheMisses']   : nil
        hits     = value['CacheHits']     ? value['CacheHits']     : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'size'   , @interval, size ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'removed', @interval, removed ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'faults' , @interval, faults ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'misses' , @interval, misses ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'stats_resourcecache', 'hits'   , @interval, hits ) )

      return result

    end



    def ParseResult_ConnectionPool( data = {} )

      result = []
      mbean  = 'ConnectionPool'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      open   = 0
      max    = 0
      idle   = 0
      busy   = 0
      min    = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        open   = value['OpenConnections']  ? value['OpenConnections']  : nil
        max    = value['MaxConnections']   ? value['MaxConnections']   : nil
        idle   = value['IdleConnections']  ? value['IdleConnections']  : nil
        busy   = value['BusyConnections']  ? value['BusyConnections']  : nil
        min    = value['MinConnections']   ? value['MinConnections']   : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'open', @interval, open ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'max' , @interval, max ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'idle', @interval, idle ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'busy', @interval, busy ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'connection_pool', 'min' , @interval, min ) )

      return result

    end


    def ParseResult_Server( data = {} )

      result       = []
      mbean        = 'Server'
      format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value        = data['value']  ? data['value']  : nil

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

  #       cacheKey = Storage::Memcached.cacheKey( { :host => @Host, :pre => 'result', :service => 'Replicator' } )
  #       replicatorData = @mc.get( memcacheKey )

        replicatorData = @mbean.bean( @Host, @serviceName, 'Replicator' )

        if( replicatorData == false )
          logger.error( sprintf( 'No mbean \'Replicator\' for Service %s found!', @serviceName ) )

          return {
            :completedSequenceNumber => 0,
            :result        => result
          }
        else

          replicatorStatus = replicatorData['status']  ? replicatorData['status']  : 505
          replicatorValue  = replicatorData['value']   ? replicatorData['value']   : nil

          if( replicatorStatus == 200 && replicatorValue != nil )

            replicatorValue         = replicatorValue.values.first

            connectionUp            = replicatorValue['ConnectionUp']                  ? replicatorValue['ConnectionUp']                  : false
            controllerState         = replicatorValue['ControllerState']               ? replicatorValue['ControllerState']               : nil
            completedSequenceNumber = replicatorValue['LatestCompletedSequenceNumber'] ? replicatorValue['LatestCompletedSequenceNumber'] : 0
            enabled                 = replicatorValue['Enabled']                       ? replicatorValue['Enabled']                       : false
            pipelineUp              = replicatorValue['PipelineUp']                    ? replicatorValue['PipelineUp']                    : false
            uncompletedCount        = replicatorValue['UncompletedCount']              ? replicatorValue['UncompletedCount']              : 0
            completedCount          = replicatorValue['CompletedCount']                ? replicatorValue['CompletedCount']                : 0

            controllerState.downcase!

            format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'

  #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'connection'              ,'up'      , @interval, connectionUp ) )
  #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'controller'              ,'state'   , @interval, controllerState ) )
            result.push( sprintf( format, @Host, @Service, 'Replicator', 'completedSequenceNumber' ,'count'   , @interval, completedSequenceNumber ) )
  #           result.push( sprintf( format, @Host, @Service, 'Replicator', 'pipeline'                ,'up'      , @interval, pipelineUp ) )
            result.push( sprintf( format, @Host, @Service, 'Replicator', 'uncompleted'             ,'count'   , @interval, uncompletedCount ) )
            result.push( sprintf( format, @Host, @Service, 'Replicator', 'completed'               ,'count'   , @interval, completedCount ) )
  #           result.push( sprintf( 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s', @Host, @Service, 'Replicator', 'enabled', @interval, enabled ) )

            return {
              :completedSequenceNumber => completedSequenceNumber,
              :result        => result
            }

          end
        end
      end


      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        # identical Data from MLS & RLS
        cacheHits             = value['ResourceCacheHits']        ? value['ResourceCacheHits']         : nil
        cacheEvicts           = value['ResourceCacheEvicts']      ? value['ResourceCacheEvicts']       : nil
        cacheEntries          = value['ResourceCacheEntries']     ? value['ResourceCacheEntries']      : nil
        cacheInterval         = value['ResourceCacheInterval']    ? value['ResourceCacheInterval']     : nil
        cacheSize             = value['ResourceCacheSize']        ? value['ResourceCacheSize']         : nil
        reqSeqNumber          = value['RepositorySequenceNumber'] ? value['RepositorySequenceNumber']  : nil
        connectionCount       = value['ConnectionCount']          ? value['ConnectionCount']           : nil
        runlevel              = value['RunLevel']                 ? value['RunLevel']                  : nil
        uptime                = value['Uptime']                   ? value['Uptime']                    : nil
        serviceInfos          = value['ServiceInfos']             ? value['ServiceInfos']              : nil
        licenseValidFrom      = value['LicenseValidFrom']         ? value['LicenseValidFrom']          : nil
        licenseValidUntilSoft = value['LicenseValidUntilSoft']    ? value['LicenseValidUntilSoft']     : nil
        licenseValidUntilHard = value['LicenseValidUntilHard']    ? value['LicenseValidUntilHard']     : nil

        # Data from RLS
        if( @Service == 'RLS' )
          replicatorData        = replicatorData()

          incomingCount         = replicatorData[:completedSequenceNumber] ? replicatorData[:completedSequenceNumber] : 0
          replicatorResult      = replicatorData[:result]                  ? replicatorData[:result]                  : nil

          if( replicatorResult != nil && replicatorResult.count != 0 )
            result = replicatorResult
          end
        end

        #in maintenance mode the Server mbean is not available
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

              named          = v['named']         ? v['named']         : 0
              namedMax       = v['maxnamed']      ? v['maxnamed']      : 0
              namedDiff      = namedMax - named
              concurrent     = v['concurrent']    ? v['concurrent']    : 0
              concurrentMax  = v['maxconcurrent'] ? v['maxconcurrent'] : 0
              concurrentDiff = concurrentMax - concurrent

              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named'          , @interval, named ) )
              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_max'      , @interval, namedMax ) )
              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'named_diff'     , @interval, namedDiff ) )
              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent'     , @interval, concurrent ) )
              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_max' , @interval, concurrentMax ) )
              result.push( sprintf( format, @Host, @Service, mbean, 'service_info', s , 'concurrent_diff', @interval, concurrentDiff ) )
            end
          end
        end

        if( licenseValidFrom != nil || licenseValidUntilSoft != nil || licenseValidUntilHard != nil)

          format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
          t      = Date.parse( Time.now().to_s )
          today  = Time.new( t.year, t.month, t.day )

          if( licenseValidFrom != nil )

            result.push( sprintf( format, @Host, @Service, mbean, 'license_from', 'raw'      , @interval, licenseValidFrom / 1000 ) )

          end


          if( licenseValidUntilSoft != nil )

            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'raw'      , @interval, licenseValidUntilSoft / 1000 ) )

            x                   = self.timeParser( today, Time.at( licenseValidUntilSoft / 1000 ) )
            validUntilSoftMonth = x[:months]
            validUntilSoftWeek  = x[:weeks]
            validUntilSoftDays  = x[:days]

            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'months' , @interval, validUntilSoftMonth ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'weeks'  , @interval, validUntilSoftWeek ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_soft', 'days'   , @interval, validUntilSoftDays ) )

          end

          if( licenseValidUntilHard != nil )

            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'raw'      , @interval, licenseValidUntilHard / 1000 ) )

            x                   = self.timeParser( today, Time.at( licenseValidUntilHard / 1000 ) )
            validUntilHardMonth = x[:months]
            validUntilHardWeek  = x[:weeks]
            validUntilHardDays  = x[:days]

            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'months' , @interval, validUntilHardMonth ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'weeks'  , @interval, validUntilHardWeek ) )
            result.push( sprintf( format, @Host, @Service, mbean, 'license_until_hard', 'days'   , @interval, validUntilHardDays ) )
          end
        end

      end

      format       = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'

      result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'hits'            , @interval, cacheHits ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'evicts'          , @interval, cacheEvicts ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'entries'         , @interval, cacheEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'interval'        , @interval, cacheInterval ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'ResourceCache', 'size'            , @interval, cacheSize ) )

      result.push( sprintf( format, @Host, @Service, mbean, 'Repository'   , 'sequence_number' , @interval, reqSeqNumber ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'connection_count', @interval, connectionCount ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'uptime'          , @interval, uptime ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server'       , 'runlevel'        , @interval, runlevel ) )

      return result

    end




    def ParseResult_StatisticsBlobStoreMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def ParseResult_StatisticsResource( data = {} )

      # was für komische
      # müssen wir klären

    end


    def ParseResult_StatisticsTextStoreMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


    def ParseResult_StatisticsPublisherMethods( data = {} )

      # was für komische
      # müssen wir klären

    end


  end

end
