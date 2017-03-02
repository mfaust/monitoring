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
