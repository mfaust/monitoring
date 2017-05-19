module CarbonData

  module Cae


    def caeDataViewFactory( data = {} )

      result    = []
      mbean     = 'DataViewFactory'
      value     = data.dig('value')

      # defaults
      lookups      = 0
      computed     = 0
      cached       = 0
      invalidated  = 0
      evicted      = 0
      activeTime   = 0
      totalTime    = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

        value = value.values.first

        lookups      = value.dig('NumberOfDataViewLookups')
        computed     = value.dig('NumberOfComputedDataViews')
        cached       = value.dig('NumberOfCachedDataViews')
        invalidated  = value.dig('NumberOfInvalidatedDataViews')
        evicted      = value.dig('NumberOfEvictedDataViews')
        activeTime   = value.dig('ActiveTimeOfComputedDataViews')
        totalTime    = value.dig('TotalTimeOfComputedDataViews')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'lookups' ),
        :value => lookups
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'computed' ),
        :value => computed
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'cached' ),
        :value => cached
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'invalidated' ),
        :value => invalidated
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'evicted' ),
        :value => evicted
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'activeTime' ),
        :value => activeTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s', @identifier, @Service, mbean, 'totalTime' ),
        :value => totalTime
      }

      return result

    end


    def caeCacheClasses( key, data = {} )

      result      = []
      mbean       = 'CacheClasses'
      value       = data.dig('value')
      status      = data.dig('status') || 404

      if( status == 404 )

        # solr 6 has no tomcat and also no manager mbean
        logger.debug( "status 404 for service #{@Service} and bean #{mbean}" )
        return
      end

      cacheClass  = key.gsub( mbean, '' )

      data['service'] = @Service

      # defaults
      capacity  = 0
      evaluated = 0
      evicted   = 0
      inserted  = 0
      removed   = 0
      level     = 0
      missRate  = 0

      if( @mbean.checkBeanConsistency( key, data ) == true && value != nil )

        value = value.values.first

        capacity  = value.dig('Capacity')
        evaluated = value.dig('Evaluated')
        evicted   = value.dig('Evicted')
        inserted  = value.dig('Inserted')
        removed   = value.dig('Removed')
        level     = value.dig('Level')
        missRate  = value.dig('MissRate')

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'evaluated' ),
        :value => evaluated
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'evicted' ),
        :value => evicted
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'inserted' ),
        :value => inserted
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'removed' ),
        :value => removed
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'level' ),
        :value => level
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'capacity' ),
        :value => capacity
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, mbean, cacheClass, 'missRate' ),
        :value => missRate
      }

      return result

    end


  end
end

