
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
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')
      request   = data.dig('request')
      solrMbean = data.dig('request', 'mbean' )
#      solrMbean = ( request != nil && request['mbean'] ) ? request['mbean'] : nil
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

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        warmupTime           = value.dig('warmupTime')
        lookups              = value.dig('lookups')
        evictions            = value.dig('evictions')
        inserts              = value.dig('inserts')
        hits                 = value.dig('hits')
        size                 = value.dig('size')
        hitratio             = value.dig('hitratio')
  #      cumulative_inserts   = value['cumulative_inserts']   ? value['cumulative_inserts']   : nil
  #      cumulative_hits      = value['cumulative_hits']      ? value['cumulative_hits']      : nil
  #      cumulative_evictions = value['cumulative_evictions'] ? value['cumulative_evictions'] : nil
  #      cumulative_hitratio  = value['cumulative_hitratio']  ? value['cumulative_hitratio']  : nil
  #      cumulative_lookups   = value['cumulative_lookups']   ? value['cumulative_lookups']   : nil
      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'warmupTime' ),
        :value => warmupTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'lookups' ),
        :value => lookups
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'evictions' ),
        :value => evictions
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'inserts' ),
        :value => inserts
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'hits' ),
        :value => hits
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'size' ),
        :value => size
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'hitratio' ),
        :value => hitratio
      }

#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'warmupTime'  , @interval, warmupTime ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'lookups'     , @interval, lookups ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'evictions'   , @interval, evictions ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'inserts'     , @interval, inserts ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hits'        , @interval, hits ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'size'        , @interval, size ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'hitratio'    , @interval, hitratio ) )

      return result

    end


    def solrQueryResultCache( data = {} )

      return self.solrCache( 'QueryResultCache', data )

    end


    def solrDocumentCache( data = {} )

      return self.solrCache( 'DocumentCache', data )

    end


    def solrReplication( data = {} )

      result    = []
      mbean     = 'Replication'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')
      request   = data.dig('request')
      solrMbean = data.dig('request', 'mbean' )
      solrCore  = self.solrCore( solrMbean )

      # defaults
      generation        = 0
      isMaster          = 0
      isSlave           = 0
      indexVersion      = 0
      requests          = 0
      medianRequestTime = 0
      timeouts          = 0
      errors            = 0
      indexSize         = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        generation        = value.dig('generation')
        isMaster          = value.dig('isSlave')
        isSlave           = value.dig('isMaster')
        indexVersion      = value.dig('indexVersion')
        generation        = value.dig('generation')
        requests          = value.dig('requests')
        medianRequestTime = value.dig('medianRequestTime')
        errors            = value.dig('errors')
#         timeouts          = value.dig('timeouts')
        indexSize         = value.dig('indexSize')
        isMaster          = value.dig('isMaster')  || 1
        isSlave           = value.dig('isSlave')   || 0

#         logger.debug( sprintf( 'index size: %s', indexSize ) )

        # achtung!
        # indexSize ist irrsinnigerweise als human readable ausgeführt worden!
        if( indexSize != nil && ( indexSize.include?( 'bytes' ) ) )
          indexSize = indexSize.gsub!( 'ytes','' )
        end

#         logger.debug( sprintf( 'index size: %s', indexSize ) )
#         logger.debug( indexSize.class.to_s )

        indexSize         = Filesize.from( indexSize ).to_i

#         logger.debug( sprintf( 'index size: %s', indexSize ) )

      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'index', 'size' ),
        :value => indexSize.to_s
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'index', 'version' ),
        :value => indexVersion
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'requests' ),
        :value => requests
#       } << {
#         :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'timeouts' ),
#         :value => timeouts
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      }

#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index_size', @interval, indexSize.to_s ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'index'     , @interval, indexVersion ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'    , @interval, errors ) )

      return result

    end


    def solrSelect( data = {} )

      result    = []
      mbean     = 'Select'
#       format    = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value     = data.dig('value')
      request   = data.dig('request')
      solrMbean = data.dig('request', 'mbean' )
      solrCore  = self.solrCore( solrMbean )

      # defaults
      avgRequestsPerSecond   = 0
      avgTimePerRequest      = 0
      medianRequestTime      = 0
      requests               = 0
      timeouts               = 0
      errors                 = 0

      if( @mbean.checkBeanConsistency( mbean, data ) == true && value != nil )

  #      value = value.values.first

        avgRequestsPerSecond   = value.dig('avgRequestsPerSecond')
        avgTimePerRequest      = value.dig('avgTimePerRequest')
        medianRequestTime      = value.dig('medianRequestTime')
        requests               = value.dig('requests')
        timeouts               = value.dig('timeouts')
        errors                 = value.dig('errors')

      end


      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'requests' ),
        :value => requests
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'timeouts' ),
        :value => timeouts
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @Host, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'requestPerSecond', 'avg' ),
        :value => avgRequestsPerSecond
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'timePerRequest', 'avg' ),
        :value => avgTimePerRequest
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @Host, @Service, solrCore, mbean, 'RequestTime', 'median' ),
        :value => medianRequestTime
      }

#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgRequestsPerSecond'  , @interval, avgRequestsPerSecond ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'avgTimePerRequest'     , @interval, avgTimePerRequest ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'medianRequestTime'     , @interval, medianRequestTime ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'requests'              , @interval, requests ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'timeouts'              , @interval, timeouts ) )
#       result.push( sprintf( format, @Host, @Service, solrCore, mbean, 'errors'                , @interval, errors ) )

      return result
    end


  end

end
