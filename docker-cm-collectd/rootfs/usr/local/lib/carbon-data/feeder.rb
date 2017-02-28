module CarbonData

  module Feeder


    def ParseResult_Health( data = {} )

      result = []
      mbean  = 'Health'
      format = 'PUTVAL %s/%s-%s-%s/gauge-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      healthy = -1 # 0: false, 1: true, -1: N/A

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        healthy   = value['Healthy']  ? value['Healthy'] : nil
        if ( healthy != nil )
          healthy           = healthy == true ? 1 : 0
        end

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'healthy', @interval, healthy ) )

      return result
    end

    # Check for the CAEFeeder
    def ParseResult_ProactiveEngine( data = {} )

      result = []
      mbean  = 'ProactiveEngine'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value'] ? data['value'] : nil

      # defaults
      maxEntries     = 0
      currentEntries = 0
      diffEntries    = 0
      invalidations  = 0
      heartbeat      = 0
      queueCapacity  = 0
      queueMaxSize   = 0
      queueSize      = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        maxEntries     = value['KeysCount']         ? value['KeysCount']         : 0  # Number of (active) keys
        currentEntries = value['ValuesCount']       ? value['ValuesCount']       : 0  # Number of (valid) values. It is less or equal to 'keysCount'
        diffEntries    = ( maxEntries - currentEntries ).to_i

        invalidations  = value['InvalidationCount'] ? value['InvalidationCount'] : nil  # Number of invalidations which have been received
        heartbeat      = value['HeartBeat']         ? value['HeartBeat']         : nil  # The heartbeat of this service: Milliseconds between now and the latest activity. A low value indicates that the service is alive. An constantly increasing value might be caused by a 'sick' or dead service
        queueCapacity  = value['QueueCapacity']     ? value['QueueCapacity']     : nil  # The queue's capacity: Maximum number of items which can be enqueued
        queueMaxSize   = value['QueueMaxSize']      ? value['QueueMaxSize']      : nil  # Maximum number of items which had been waiting in the queue
        queueSize      = value['QueueSize']         ? value['QueueSize']         : nil  # Number of items waiting in the queue for being processed. Less or equal than 'queueCapacity'. Zero means that ProactiveEngine is idle.

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'max'          , @interval, maxEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'current'      , @interval, currentEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'diff'         , @interval, diffEntries ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'invalidations', @interval, invalidations ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'feeder', 'heartbeat'    , @interval, heartbeat ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'capacity'     , @interval, queueCapacity ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'max_waiting'  , @interval, queueMaxSize ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'queue' , 'waiting'      , @interval, queueSize ) )

      return result
    end




    def ParseResult_Feeder( data = {} )

      result = []
      mbean  = 'Feeder'
      format = 'PUTVAL %s/%s-%s-%s/count-%s interval=%s N:%s'
      value  = data['value']  ? data['value']  : nil

      # defaults
      pendingEvents           = 0
      indexDocuments          = 0
      indexContentDocuments   = 0
      currentPendingDocuments = 0

      if( @mbean.checkBean‎Consistency( mbean, data ) == true && value != nil )

        value = value.values.first

        pendingEvents           = value['PendingEvents']              ? value['PendingEvents']              : nil
        indexDocuments          = value['IndexDocuments']             ? value['IndexDocuments']             : nil
        indexContentDocuments   = value['IndexContentDocuments']      ? value['IndexContentDocuments']      : nil
        currentPendingDocuments = value['CurrentPendingDocuments']    ? value['CurrentPendingDocuments']    : nil

      end

      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'pending_events'            , @interval, pendingEvents ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_documents'           , @interval, indexDocuments ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'index_content_documents'   , @interval, indexContentDocuments ) )
      result.push( sprintf( format, @Host, @Service, mbean, 'server', 'current_pending_documents' , @interval, currentPendingDocuments ) )

      return result

    end

    
  end


end
