module CarbonData

  module Cae



    def ParseResult_DataViewFactory( data = {} )

      result    = []
      mbean     = 'DataViewFactory'
      format    = 'PUTVAL %s/%s-%s/count-%s interval=%s N:%s'
      value     = data['value']     ? data['value']     : nil

      # defaults
      lookups      = 0
      computed     = 0
      cached       = 0
      invalidated  = 0
      evicted      = 0
      activeTime   = 0
      totalTime    = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        lookups      = value['NumberOfDataViewLookups']       ? value['NumberOfDataViewLookups']       : nil
        computed     = value['NumberOfComputedDataViews']     ? value['NumberOfComputedDataViews']     : nil
        cached       = value['NumberOfCachedDataViews']       ? value['NumberOfCachedDataViews']       : nil
        invalidated  = value['NumberOfInvalidatedDataViews']  ? value['NumberOfInvalidatedDataViews']  : nil
        evicted      = value['NumberOfEvictedDataViews']      ? value['NumberOfEvictedDataViews']      : nil
        activeTime   = value['ActiveTimeOfComputedDataViews'] ? value['ActiveTimeOfComputedDataViews'] : nil
        totalTime    = value['TotalTimeOfComputedDataViews']  ? value['TotalTimeOfComputedDataViews']  : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'lookups'     , @interval, lookups ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'computed'    , @interval, computed ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'cached'      , @interval, cached ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'invalidated' , @interval, invalidated ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'evicted'     , @interval, evicted ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'activeTime'  , @interval, activeTime ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'totalTime'   , @interval, totalTime ) )

      return result

    end



    def ParseResult_CacheClasses( key, data = {} )

      result = []
      mbean  = 'CacheClasses'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil
      cacheClass = key.gsub( mbean, '' )

      data['service'] = @Service

  #     logger.debug( data )

      # defaults
      capacity  = 0
      evaluated = 0
      evicted   = 0
      inserted  = 0
      removed   = 0
      level     = 0
      missRate  = 0

      if( @mbean.checkBean‎Consistency( key, data ) == true && value != nil )

        value = value.values.first

        capacity  = value['Capacity']    ? value['Capacity']    : nil
        evaluated = value['Evaluated']   ? value['Evaluated']   : nil
        evicted   = value['Evicted']     ? value['Evicted']     : nil
        inserted  = value['Inserted']    ? value['Inserted']    : nil
        removed   = value['Removed']     ? value['Removed']     : nil
        level     = value['Level']       ? value['Level']       : nil
        missRate  = value['MissRate']    ? value['MissRate']    : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'evaluated' , @interval, evaluated ) )
      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'evicted'   , @interval, evicted ) )
      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'inserted'  , @interval, inserted ) )
      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'removed'   , @interval, removed ) )

      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'level'     , @interval, level ) )
      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'capacity'  , @interval, capacity ) )
      result.push( sprintf( format, @Host, @Service, mbean, cacheClass, 'missRate'  , @interval, missRate ) )

      return result

    end



  end
end

