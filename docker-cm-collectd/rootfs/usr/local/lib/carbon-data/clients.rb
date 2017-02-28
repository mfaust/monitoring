module CarbonData

  module Clients



    def ParseResult_MemoryPool( data = {} )

      result  = []
      mbean   = 'MemoryPool'
      format  = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value   = data['value']    ? data['value']    : nil
      request = data['request']  ? data['request']  : nil
      bean    = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
      usage   = ( value != nil && ['Usage'] )          ? value['Usage']   : nil

      # defaults
      init      = 0
      max       = 0
      used      = 0
      committed = 0
      percent   = 0
      mbeanName = @mbean.beanName( bean )
      mbeanName = mbeanName.strip.tr( ' ', '_' )

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil && usage != nil )

        init      = usage['init']       ? usage['init']      : nil
        max       = usage['max']        ? usage['max']       : nil
        used      = usage['used']       ? usage['used']      : nil
        committed = usage['committed']  ? usage['committed'] : nil

        if( max != -1 )
          percent   = ( 100 * used / max )
        else
          percent   = ( 100 * used / committed )
        end

      end

      result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'init'        , @interval, init ) )
      result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'committed'   , @interval, committed ) )
      result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'max'         , @interval, max ) )
      result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'used'        , @interval, used ) )
      result.push( sprintf( format, @Host, @Service, mbean, mbeanName, 'used_percent', @interval, percent ) )

      return result
    end



    def ParseResult_CapConnection( data = {} )

      result = []
      mbean  = 'CapConnection'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

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

        blobCacheSize    = value['BlobCacheSize']        ? value['BlobCacheSize']      : nil
        blobCacheLevel   = value['BlobCacheLevel']       ? value['BlobCacheLevel']     : nil
        blobCacheFaults  = value['BlobCacheFaults']      ? value['BlobCacheFaults']    : nil
        blobCachePercent = ( 100 * blobCacheLevel.to_i / blobCacheSize.to_i ).to_i

        heapCacheSize    = value['HeapCacheSize']        ? value['HeapCacheSize']      : nil
        heapCacheLevel   = value['HeapCacheLevel']       ? value['HeapCacheLevel']     : nil
        heapCacheFaults  = value['HeapCacheFaults']      ? value['HeapCacheFaults']    : nil
        heapCachePercent = ( 100 * heapCacheLevel.to_i / heapCacheSize.to_i ).to_i

        suSessions       = value['NumberOfSUSessions']   ? value['NumberOfSUSessions'] : nil

        connectionOpen   = (value['Open']  != nil)       ? value['Open']               : nil
        if ( connectionOpen != nil )
          open           = connectionOpen ? 1 : 0
        end
      end

      result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'size'        , @interval, blobCacheSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used'        , @interval, blobCacheLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'fault'       , @interval, blobCacheFaults ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'blob_cache', 'used_percent', @interval, blobCachePercent ) )

      result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'size'        , @interval, heapCacheSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used'        , @interval, heapCacheLevel ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'fault'       , @interval, heapCacheFaults ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'heap_cache', 'used_percent', @interval, heapCachePercent ) )

      result.push( sprintf( format, @Host, @Service, mbean, 'su_sessions', 'sessions'   , @interval, suSessions ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'open'       , 'open'       , @interval, open ) )

      return result

    end



    def ParseResult_TransformedBlobCacheManager( data = {} )

      result    = []
      mbean     = 'TransformedBlobCacheManager'
      format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data['value']     ? data['value']     : nil

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

        cacheSize               = value['CacheSize']                 ? value['CacheSize']                 : nil
        cacheLevel              = value['Level']                     ? value['Level']                     : nil
        cacheInitialLevel       = value['InitialLevel']              ? value['InitialLevel']              : nil
        newGenCacheSize         = value['NewGenerationCacheSize']    ? value['NewGenerationCacheSize']    : nil
        newGenCacheLevel        = value['NewGenerationLevel']        ? value['NewGenerationLevel']        : nil
        newGenCacheInitialLevel = value['NewGenerationInitialLevel'] ? value['NewGenerationInitialLevel'] : nil
        oldGenCacheLevel        = value['OldGenerationLevel']        ? value['OldGenerationLevel']        : nil
        oldGenCacheInitialLevel = value['OldGenerationInitialLevel'] ? value['OldGenerationInitialLevel'] : nil
        faultSize               = value['FaultSizeSum']              ? value['FaultSizeSum']              : nil
        fault                   = value['FaultCount']                ? value['FaultCount']                : nil
        recallSize              = value['RecallSizeSum']             ? value['RecallSizeSum']             : nil
        recall                  = value['RecallCount']               ? value['RecallCount']               : nil
        rotate                  = value['RotateCount']               ? value['RotateCount']               : nil
        access                  = value['AccessCount']               ? value['AccessCount']               : nil

      end

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


    
  end

end
