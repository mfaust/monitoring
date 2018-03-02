module CarbonData

  module Feeder


    def feederHealth( data = {} )

      result      = []
      mbean       = 'Health'
      value       = data.dig('value')

      # defines:
      #   0: false
      #   1: true
      #  -1: N/A
      healthy = -1

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        healthy   = value.dig('Healthy')
        healthy   = healthy == true ? 1 : 0 if ( healthy != nil )
      end

      result << {
        :key   => format( '%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'healthy' ),
        :value => healthy
      }

      result
    end


    # Check for the CAEFeeder
    def feederProactiveEngine( data = {} )

      result      = []
      mbean       = 'ProactiveEngine'
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

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

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
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'feeder', 'entries', 'max' ),
        :value => maxEntries
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'feeder', 'entries', 'current' ),
        :value => currentEntries
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'feeder', 'entries', 'diff' ),
        :value => diffEntries
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'feeder', 'invalidations' ),
        :value => invalidations
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'feeder', 'heartbeat' ),
        :value => heartbeat
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'queue', 'capacity' ),
        :value => queueCapacity
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'queue', 'max_waiting' ),
        :value => queueMaxSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'queue', 'waiting' ),
        :value => queueSize
      }

      result
    end


    def feederFeeder( data = {} )

      result = []
      mbean  = 'Feeder'
      value       = data.dig('value')

      # defaults
      pendingEvents           = 0
      indexDocuments          = 0
      indexContentDocuments   = 0
      currentPendingDocuments = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        pendingEvents           = value.dig('PendingEvents')
        indexDocuments          = value.dig('IndexDocuments')
        indexContentDocuments   = value.dig('IndexContentDocuments')
        currentPendingDocuments = value.dig('CurrentPendingDocuments')
      end

      result << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'pending_events' ),
        :value => pendingEvents
      } << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'index_documents' ),
        :value => indexDocuments
      } << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'index_content_documents' ),
        :value => indexContentDocuments
      } << {
        :key   => format( '%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'current_pending_documents' ),
        :value => currentPendingDocuments
      }

      result
    end


    def feederTransformedBlobCacheManager( data = {} )

      result    = []
      mbean     = 'TransformedBlobCacheManager'
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

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

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
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'cache', 'size' ),
        :value => cacheSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'cache', 'level' ),
        :value => cacheLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'cache', 'initial_level' ),
        :value => cacheInitialLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'new_gen', 'size' ),
        :value => newGenCacheSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'new_gen', 'level' ),
        :value => newGenCacheLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'new_gen', 'initial_level' ),
        :value => newGenCacheInitialLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'old_gen', 'size' ),
        :value => oldGenCacheLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @normalized_service_name, mbean, 'cache', 'old_gen', 'initial_level' ),
        :value => oldGenCacheInitialLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'fault', 'count' ),
        :value => fault
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'fault', 'size' ),
        :value => faultSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'recall', 'count' ),
        :value => recall
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @normalized_service_name, mbean, 'recall', 'size' ),
        :value => recallSize
      } << {
        :key   => format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, mbean, 'rotate' ),
        :value => rotate
      } << {
        :key   => format( '%s.%s.%s.%s'      , @identifier, @normalized_service_name, mbean, 'access' ),
        :value => access
      }

      result
    end
  end
end
