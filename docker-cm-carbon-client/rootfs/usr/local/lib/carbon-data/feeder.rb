module CarbonData

  module Feeder


    def feederHealth( data = {} )

      result      = []
      mbean       = 'Health'
#       format      = 'PUTVAL %s/%s-%s-%s/gauge-%s interval=%s N:%s'
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
        :key   => sprintf( '%s.%s.%s.%s', @Host, @Service, mbean, 'healthy' ),
        :value => healthy
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'healthy', @interval, healthy ) )

      return result
    end


    # Check for the CAEFeeder
    def feederProactiveEngine( data = {} )

      result      = []
      mbean       = 'ProactiveEngine'
#       format      = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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

#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max'          , @interval, maxEntries ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current'      , @interval, currentEntries ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff'         , @interval, diffEntries ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'invalidations', @interval, invalidations ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'heartbeat'    , @interval, heartbeat ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'capacity'     , @interval, queueCapacity ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'max_waiting'  , @interval, queueMaxSize ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'waiting'      , @interval, queueSize ) )

      return result
    end


    def feederFeeder( data = {} )

      result = []
      mbean  = 'Feeder'
#       format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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

#       result.push( sprintf( format, @Host, @Service, mbean, 'server', 'pending_events'            , @interval, pendingEvents ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_documents'           , @interval, indexDocuments ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )

      return result

    end


    def feederTransformedBlobCacheManager( data = {} )

      result    = []
      mbean     = 'TransformedBlobCacheManager'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      cacheSize          = 0   # set the cache size in bytes
      cacheLevel         = 0   # cache level in bytes
      cacheInitialLevel  = 0   # initial cache level in bytes
      newGenCacheSize    = 0   # cache size of new generation folder in bytes
      newGenLevel        = 0   # cache level of the new generation in bytes
      newGenInitialLevel = 0   # initial cache level of the new generation in bytes
      oldGenLevel        = 0   # cache level of the old generation in bytes
      oldGenInitialLevel = 0   # initial cache level of the old generation level in bytes
      faultSizeSum       = 0   # sum of sizes in bytes of all blobs faulted since system start
      faultCount         = 0   # count of faults since system start
      recallSizeSum      = 0   # sum of sizes in bytes of all blobs recalled since system start
      recallCount        = 0   # count of recalls since system start
      rotateCount        = 0   # count of rotates since system start
      accessCount        = 0   # count of accesses since system start

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        cacheSize               = value.dig('CacheSize')
        cacheLevel              = value.dig('Level')
        cacheInitialLevel       = value.dig('InitialLevel')
        newGenCacheSize         = value.dig('NewGenerationCacheSize')
        newGenCacheLevel        = value.dig('NewGenerationLevel')
        newGenCacheInitialLevel = value.dig('NewGenerationInitialLevel')
        oldGenCacheLevel        = value.dig('OldGenerationLevel')
        oldGenCacheInitialLevel = value.dig('OldGenerationInitialLevel')
        faultSize               = value.dig('FaultSizeSum')
        fault                   = value.dig('FaultCount')
        recallSize              = value.dig('RecallSizeSum')
        recall                  = value.dig('RecallCount')
        rotate                  = value.dig('RotateCount')
        access                  = value.dig('AccessCount')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'cache', 'size' ),
        :value => cacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'cache', 'level' ),
        :value => cacheLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'cache', 'initial_level' ),
        :value => cacheInitialLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'new_gen', 'size' ),
        :value => newGenCacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'new_gen', 'level' ),
        :value => newGenCacheLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'new_gen', 'initial_level' ),
        :value => newGenCacheInitialLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'old_gen', 'size' ),
        :value => oldGenCacheLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'cache', 'old_gen', 'initial_level' ),
        :value => oldGenCacheInitialLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'fault', 'count' ),
        :value => fault
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'fault', 'size' ),
        :value => faultSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'recall', 'count' ),
        :value => recall
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'recall', 'size' ),
        :value => recallSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, mbean, 'rotate' ),
        :value => rotate
      } << {
        :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, mbean, 'access' ),
        :value => access
      }

#      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'size'          , @interval, cacheSize ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'level'         , @interval, cacheLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'initial_level' , @interval, cacheInitialLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'size'          , @interval, newGenCacheSize ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'level'         , @interval, newGenCacheLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'initial_level' , @interval, newGenCacheInitialLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'level'         , @interval, oldGenCacheLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'initial_level' , @interval, oldGenCacheInitialLevel ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'count'         , @interval, fault ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'size'          , @interval, faultSize ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'count'         , @interval, recall ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'size'          , @interval, recallSize ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'rotate'      , 'count'         , @interval, rotate ) )
#      result.push( sprintf( format, @Host, @Service, mbean, 'access'      , 'count'         , @interval, access ) )

      return result

    end


  end


end
