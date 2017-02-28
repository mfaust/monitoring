
module CarbonData

  module Solr


    def solrCore( mbean )

      regex = /
        ^                     # Starting at the front of the string
        solr\/                #
        (?<core>.+[a-zA-Z0-9]):  #
        (.*)                  #
        type=                 #
        (?<type>.+[a-zA-Z])   #
        $
      /x

      parts          = mbean.match( regex )

      return sprintf( 'core_%s', parts['core'].to_s.strip.tr( '. ', '' ).downcase )

    end


    def solrCache( mbean, data = {} )

      result    = []
      format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data['value']    ? data['value']   : nil
      request   = data['request']  ? data['request'] : nil
      solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
      solrCore  = self.solrCore( solrMbean )

      # defaults
      warmupTime           = 0
      lookups              = 0
      evictions            = 0
      inserts              = 0
      hits                 = 0
      size                 = 0
      hitratio             = 0
      cumulative_inserts   = 0
      cumulative_hits      = 0
      cumulative_evictions = 0
      cumulative_hitratio  = 0
      cumulative_lookups   = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        warmupTime           = value['warmupTime']           ? value['warmupTime']           : nil
        lookups              = value['lookups']              ? value['lookups']              : nil
        evictions            = value['evictions']            ? value['evictions']            : nil
        inserts              = value['inserts']              ? value['inserts']              : nil
        hits                 = value['hits']                 ? value['hits']                 : nil
        size                 = value['size']                 ? value['size']                 : nil
        hitratio             = value['hitratio']             ? value['hitratio']             : nil
  #      cumulative_inserts   = value['cumulative_inserts']   ? value['cumulative_inserts']   : nil
  #      cumulative_hits      = value['cumulative_hits']      ? value['cumulative_hits']      : nil
  #      cumulative_evictions = value['cumulative_evictions'] ? value['cumulative_evictions'] : nil
  #      cumulative_hitratio  = value['cumulative_hitratio']  ? value['cumulative_hitratio']  : nil
  #      cumulative_lookups   = value['cumulative_lookups']   ? value['cumulative_lookups']   : nil
      end

      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'warmupTime'  , @interval, warmupTime ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'lookups'     , @interval, lookups ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'evictions'   , @interval, evictions ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'inserts'     , @interval, inserts ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hits'        , @interval, hits ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'size'        , @interval, size ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hitratio'    , @interval, hitratio ) )

      return result

    end


    def ParseResult_SolrQueryResultCache( data = {} )

      mbean     = 'QueryResultCache'

      return self.solrCache( mbean, data )

    end


    def ParseResult_SolrDocumentCache( data = {} )

      mbean     = 'DocumentCache'

      return self.solrCache( mbean, data )

    end


    def ParseResult_SolrReplication( data = {} )

      result    = []
      mbean     = 'Replication'
      format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data['value']    ? data['value']   : nil
      request   = data['request']  ? data['request'] : nil
      solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
      solrCore  = self.solrCore( solrMbean )

      # defaults
      generation        = 0
      isMaster          = 0
      isSlave           = 0
      indexVersion      = 0
      requests          = 0
      medianRequestTime = 0
      errors            = 0
      indexSize         = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        generation        = value['generation']        ? value['generation']        : nil
        isMaster          = value['isSlave']           ? value['isSlave']           : nil
        isSlave           = value['isMaster']          ? value['isMaster']          : nil
        indexVersion      = value['indexVersion']      ? value['indexVersion']      : nil
        requests          = value['requests']          ? value['requests']          : nil
        medianRequestTime = value['medianRequestTime'] ? value['medianRequestTime'] : nil
        errors            = value['errors']            ? value['errors']            : nil
        indexSize         = value['indexSize']         ? value['indexSize']         : nil
        # achtung!
        # indexSize ist irrsinnigerweise als human readable ausgeführt worden!
        if( indexSize != nil && ( indexSize.include?( 'bytes' ) ) )
          indexSize = indexSize.gsub!( 'ytes','' )
        end
        indexSize         = Filesize.from( indexSize ).to_i

      end

      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index_size', @interval, indexSize.to_s ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index'     , @interval, indexVersion ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'    , @interval, errors ) )

      return result

    end


    def ParseResult_SolrSelect( data = {} )

      result    = []
      mbean     = 'Select'
      format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data['value']    ? data['value']   : nil
      request   = data['request']  ? data['request'] : nil
      solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
      solrCore  = self.solrCore( solrMbean )

      # defaults
      avgRequestsPerSecond   = 0
      avgTimePerRequest      = 0
      medianRequestTime      = 0
      requests               = 0
      timeouts               = 0
      errors                 = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        avgRequestsPerSecond   = value['avgRequestsPerSecond']   ? value['avgRequestsPerSecond'] : nil
        avgTimePerRequest      = value['avgTimePerRequest']      ? value['avgTimePerRequest']    : nil
        medianRequestTime      = value['medianRequestTime']      ? value['medianRequestTime']    : nil
        requests               = value['requests']               ? value['requests']             : nil
        timeouts               = value['timeouts']               ? value['timeouts']             : nil
        errors                 = value['errors']                 ? value['errors']               : nil

      end

      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgRequestsPerSecond'  , @interval, avgRequestsPerSecond ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgTimePerRequest'     , @interval, avgTimePerRequest ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'medianRequestTime'     , @interval, medianRequestTime ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'requests'              , @interval, requests ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'timeouts'              , @interval, timeouts ) )
      result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'                , @interval, errors ) )

      return result
    end


  end

end
