module CarbonData

  module Clients

    def clientsCapConnection( data = {} )

      result    = []
      mbean     = 'CapConnection'
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

      # defines:
      #   0: false
      #   1: true
      #  -1: N/A
      open             = -1

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

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
        open = connectionOpen ? 1 : 0 if( connectionOpen != nil )
      end


      result << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'blob', 'cache', 'size' ),
        :value => blobCacheSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'blob', 'cache', 'used' ),
        :value => blobCacheLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'blob', 'cache', 'fault' ),
        :value => blobCacheFaults
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'blob', 'cache', 'used_percent' ),
        :value => blobCachePercent
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'heap', 'cache', 'size' ),
        :value => heapCacheSize
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'heap', 'cache', 'used' ),
        :value => heapCacheLevel
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'heap', 'cache', 'fault' ),
        :value => heapCacheFaults
      } << {
        :key   => format( '%s.%s.%s.%s.%s.%s', @identifier, @Service, mbean, 'heap', 'cache', 'used_percent' ),
        :value => heapCachePercent
      } << {
        :key   => format( '%s.%s.%s.%s.%s'   , @identifier, @Service, mbean, 'su_sessions', 'sessions' ),
        :value => suSessions
      } << {
        :key   => format( '%s.%s.%s.%s'      , @identifier, @Service, mbean, 'open' ),
        :value => open
      }

      result
    end


    def clientsMemoryPool( key, data = {} )

      result  = []
      mbean   = 'MemoryPool'
      value   = data.dig('value')
      request = data.dig('request')
      bean    = data.dig('request', 'mbean')
      usage   = data.dig('value', 'Usage')

      # defaults
      init      = 0
      max       = 0
      used      = 0
      committed = 0
      percent   = 0
      mbeanName = @mbean.beanName( bean )
      mbeanName = mbeanName.strip.tr( ' ', '_' )

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil && usage != nil )

        init      = usage.dig('init')
        max       = usage.dig('max')
        used      = usage.dig('used')
        committed = usage.dig('committed')

        percent   = ( 100 * used / committed )
        percent   = ( 100 * used / max ) if( max != -1 )
      end

      result << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, mbeanName, 'init' ),
        :value => init
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, mbeanName, 'committed' ),
        :value => committed
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, mbeanName, 'max' ),
        :value => max
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, mbeanName, 'used_percent' ),
        :value => percent
      } << {
        :key   => format( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, mbeanName, 'used' ),
        :value => used
      }

      result
    end


  end

end
