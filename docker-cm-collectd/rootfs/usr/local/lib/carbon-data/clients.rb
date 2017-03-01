module CarbonData

  module Clients



    def clientsCapConnection( data = {} )

      result    = []
      mbean     = 'CapConnection'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')

      # defaults
      blobCacheSize    = 0
      blobCacheLevel   = 0
      blobCacheFaults  = 0
      blobCachePercent = 0
      heapCacheSize    = 0
      heapCacheLevel   = 0
      heapCacheFaults  = 0
      heapCachePercent = 0
      suSessions       = 0
      open             = -1 # 0: false, 1: true, -1: N/A

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        blobCacheSize    = value.dig('BlobCacheSize')
        blobCacheLevel   = value.dig('BlobCacheLevel')
        blobCacheFaults  = value.dig('BlobCacheFaults')
        blobCachePercent = ( 100 * blobCacheLevel.to_i / blobCacheSize.to_i ).to_i

        heapCacheSize    = value.dig('HeapCacheSize')
        heapCacheLevel   = value.dig('HeapCacheLevel')
        heapCacheFaults  = value.dig('HeapCacheFaults')
        heapCachePercent = ( 100 * heapCacheLevel.to_i / heapCacheSize.to_i ).to_i

        suSessions       = value.dig('NumberOfSUSessions')

        connectionOpen   = value.dig('Open')
        if ( connectionOpen != nil )
          open           = connectionOpen ? 1 : 0
        end
      end


      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'blob', 'cache', 'size' ),
        :value => blobCacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'blob', 'cache', 'used' ),
        :value => blobCacheLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'blob', 'cache', 'fault' ),
        :value => blobCacheFaults
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'blob', 'cache', 'used_percent' ),
        :value => blobCachePercent
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'heap', 'cache', 'size' ),
        :value => heapCacheSize
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'heap', 'cache', 'used' ),
        :value => heapCacheLevel
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'heap', 'cache', 'fault' ),
        :value => heapCacheFaults
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, mbean, 'heap', 'cache', 'used_percent' ),
        :value => heapCachePercent
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, mbean, 'su_sessions', 'sessions' ),
        :value => suSessions
      } << {
        :key   => sprintf( '%s.%s.%s.%s'      , @Host, @Service, mbean, 'open' ),
        :value => open
      }

#       result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'size'        , @interval, blobCacheSize ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used'        , @interval, blobCacheLevel ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'fault'       , @interval, blobCacheFaults ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used_percent', @interval, blobCachePercent ) )
#
#       result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'size'        , @interval, heapCacheSize ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used'        , @interval, heapCacheLevel ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'fault'       , @interval, heapCacheFaults ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used_percent', @interval, heapCachePercent ) )
#
#       result.push( sprintf( format, @Host, @Service, mbean, 'su_sessions', 'sessions'   , @interval, suSessions ) )
#       result.push( sprintf( format, @Host, @Service, mbean, 'open'       , 'open'       , @interval, open ) )

      return result

    end


    def clientsTransformedBlobCacheManager( data = {} )

      result    = []
      mbean     = 'TransformedBlobCacheManager'
      format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
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
      }




      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'size'          , @interval, cacheSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'level'         , @interval, cacheLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'cache'       , 'initial_level' , @interval, cacheInitialLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'size'          , @interval, newGenCacheSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'level'         , @interval, newGenCacheLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'newGen_cache', 'initial_level' , @interval, newGenCacheInitialLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'level'         , @interval, oldGenCacheLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'oldGen_cache', 'initial_level' , @interval, oldGenCacheInitialLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'count'         , @interval, fault ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'fault'       , 'size'          , @interval, faultSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'count'         , @interval, recall ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'recall'      , 'size'          , @interval, recallSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'rotate'      , 'count'         , @interval, rotate ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'access'      , 'count'         , @interval, access ) )

      return result

    end


    def clientsMemoryPool( key, data = {} )

      result  = []
      mbean   = 'MemoryPool'
      value   = data.dig('value')
      request = data.dig('request')
      bean    = data.dig('request', 'mbean') # ( request != nil && request['mbean'] ) ? request['mbean'] : nil
      usage   = data.dig('value', 'Usage')   # ( value != nil && ['Usage'] )          ? value['Usage']   : nil

      # defaults
      init      = 0
      max       = 0
      used      = 0
      committed = 0
      percent   = 0
      mbeanName = @mbean.beanName( bean )
      mbeanName = mbeanName.strip.tr( ' ', '_' )

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil && usage != nil )

        init      = usage.dig('init')
        max       = usage.dig('max')
        used      = usage.dig('used')
        committed = usage.dig('committed')

        if( max != -1 )
          percent   = ( 100 * used / max )
        else
          percent   = ( 100 * used / committed )
        end

      end


      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, mbeanName, 'init' ),
        :value => init
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, mbeanName, 'committed' ),
        :value => committed
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, mbeanName, 'max' ),
        :value => max
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, mbeanName, 'used_percent' ),
        :value => percent
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, mbean, mbeanName, 'used' ),
        :value => used
      }

      return result
    end




  end

end
