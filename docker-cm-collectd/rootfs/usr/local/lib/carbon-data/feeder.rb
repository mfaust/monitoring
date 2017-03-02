module CarbonData

  module Feeder


    def feederHealth( data = {} )

      result      = []
      mbean       = 'Health'
      format      = 'PUTVAL %s/%s-%s-%s/gauge-%s interval=%s N:%s'
      value       = data.dig('value')

      # defaults
      healthy = -1 # 0: false, 1: true, -1: N/A

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        healthy   = value.dig('Healthy')
        if ( healthy != nil )
          healthy           = healthy == true ? 1 : 0
        end

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, 'feeder', 'healthy' ),
        :value => healthy
      }

      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'healthy', @interval, healthy ) )

      return result
    end


    # Check for the CAEFeeder
    def feederProactiveEngine( data = {} )

      result      = []
      mbean       = 'ProactiveEngine'
      format      = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value       = data.dig('value')

      # defaults
      maxEntries     = 0  # (KeysCount) Number of (active) keys
      currentEntries = 0  # (ValuesCount) Number of (valid) values. It is less or equal to 'keysCount'
      diffEntries    = 0  #
      invalidations  = 0  # (InvalidationCount) Number of invalidations which have been received
      heartbeat      = 0  # (HeartBeat) The heartbeat of this service: Milliseconds between now and the latest activity. A low value indicates that the service is alive. An constantly increasing value might be caused by a 'sick' or dead service
      queueCapacity  = 0  # (QueueCapacity) The queue's capacity: Maximum number of items which can be enqueued
      queueMaxSize   = 0  # (QueueMaxSize) Maximum number of items which had been waiting in the queue
      queueSize      = 0  # (QueueSize) Number of items waiting in the queue for being processed. Less or equal than 'queueCapacity'. Zero means that ProactiveEngine is idle.

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        maxEntries     = value.dig('KeysCount')   || 0
        currentEntries = value.dig('ValuesCount') || 0
        diffEntries    = ( maxEntries - currentEntries ).to_i

        invalidations  = value.dig('InvalidationCount')
        heartbeat      = value.dig('HeartBeat')
        queueCapacity  = value.dig('QueueCapacity')
        queueMaxSize   = value.dig('QueueMaxSize')
        queueSize      = value.dig('QueueSize')

      end



      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'feeder', 'entries', 'max' ),
        :value => maxEntries
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'feeder', 'entries', 'current' ),
        :value => currentEntries
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'feeder', 'entries', 'diff' ),
        :value => diffEntries
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'feeder', 'invalidations' ),
        :value => invalidations
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'feeder', 'heartbeat' ),
        :value => heartbeat
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'queue', 'capacity' ),
        :value => queueCapacity
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'queue', 'max_waiting' ),
        :value => queueMaxSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'queue', 'waiting' ),
        :value => queueSize
      }



      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max'          , @interval, maxEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current'      , @interval, currentEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff'         , @interval, diffEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'invalidations', @interval, invalidations ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'heartbeat'    , @interval, heartbeat ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'capacity'     , @interval, queueCapacity ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'max_waiting'  , @interval, queueMaxSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'waiting'      , @interval, queueSize ) )

      return result
    end


    def feederFeeder( data = {} )

      result = []
      mbean  = 'Feeder'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value       = data.dig('value')

      # defaults
      pendingEvents           = 0
      indexDocuments          = 0
      indexContentDocuments   = 0
      currentPendingDocuments = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        pendingEvents           = value.dig('PendingEvents')
        indexDocuments          = value.dig('IndexDocuments')
        indexContentDocuments   = value.dig('IndexContentDocuments')
        currentPendingDocuments = value.dig('CurrentPendingDocuments')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'pending_events' ),
        :value => pendingEvents
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'index_documents' ),
        :value => indexDocuments
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'index_content_documents' ),
        :value => indexContentDocuments
      } << {
        :key   => sprintf( '%s.%s.%s.%s'   , @Host, @Service, mbean, 'current_pending_documents' ),
        :value => currentPendingDocuments
      }



      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'pending_events'            , @interval, pendingEvents ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_documents'           , @interval, indexDocuments ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )

      return result

    end


  end


end
