
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

        warmupTime           = value.dig('warmupTime')
        lookups              = value.dig('lookups')
        evictions            = value.dig('evictions')
        inserts              = value.dig('inserts')
        hits                 = value.dig('hits')
        size                 = value.dig('size')
        hitratio             = value.dig('hitratio')
      end

      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'warmupTime' ),
        :value => warmupTime
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'lookups' ),
        :value => lookups
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'evictions' ),
        :value => evictions
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'inserts' ),
        :value => inserts
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'hits' ),
        :value => hits
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'size' ),
        :value => size
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'hitratio' ),
        :value => hitratio
      }

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

        generation        = value.dig('generation')
        isMaster          = value.dig('isSlave')
        isSlave           = value.dig('isMaster')
        indexVersion      = value.dig('indexVersion')
        generation        = value.dig('generation')
        requests          = value.dig('requests')
        medianRequestTime = value.dig('medianRequestTime')
        errors            = value.dig('errors')
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
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'index', 'size' ),
        :value => indexSize.to_s
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'index', 'version' ),
        :value => indexVersion
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'requests' ),
        :value => requests
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      }

      return result

    end


    def solrSelect( data = {} )

      result    = []
      mbean     = 'Select'
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

        avgRequestsPerSecond   = value.dig('avgRequestsPerSecond')
        avgTimePerRequest      = value.dig('avgTimePerRequest')
        medianRequestTime      = value.dig('medianRequestTime')
        requests               = value.dig('requests')
        timeouts               = value.dig('timeouts')
        errors                 = value.dig('errors')

      end


      result << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'requests' ),
        :value => requests
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'timeouts' ),
        :value => timeouts
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s'   , @identifier, @Service, solrCore, mbean, 'errors' ),
        :value => errors
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'requestPerSecond', 'avg' ),
        :value => avgRequestsPerSecond
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'timePerRequest', 'avg' ),
        :value => avgTimePerRequest
      } << {
        :key   => sprintf( '%s.%s.%s.%s.%s.%s', @identifier, @Service, solrCore, mbean, 'RequestTime', 'median' ),
        :value => medianRequestTime
      }

      return result
    end


  end

end
