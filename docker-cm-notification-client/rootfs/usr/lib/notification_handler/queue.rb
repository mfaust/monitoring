
module NotificationHandler

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue

      data = @mq_consumer.getJobFromTube( @mq_queue )

      if( data.count() != 0 )

        stats = @mq_consumer.tubeStatistics( @mq_queue )
        logger.debug( {
          :total   => stats.dig(:total),
          :ready   => stats.dig(:ready),
          :delayed => stats.dig(:delayed),
          :buried  => stats.dig(:buried)
        } )

        if( stats.dig(:ready).to_i > 10 )
          logger.warn( 'more then 10 jobs in queue ... just wait' )

          @mq_consumer.cleanQueue( @mq_queue )
          return
        end

        jobId  = data.dig( :id )

        result = process_queue( data )

        status = result.dig(:status).to_i

        if( status == 200 || status == 409 || status == 500 || status == 503 )

          @mq_consumer.deleteJob( @mq_queue, jobId )
        else

          @mq_consumer.buryJob( @mq_queue, jobId )
        end
      end

    end


    def process_queue( data )

      logger.info( sprintf( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

      logger.debug( data )

      command    = data.dig(:body, 'cmd')
      node       = data.dig(:body, 'node')
      payload    = data.dig(:body, 'payload')
      @timestamp = nil

      #
      #
      if( command == nil || node == nil || payload == nil )

        status = 500

        if( command == nil )
          e = 'missing command'
          logger.error( e )
          logger.error( data )
          return { :status  => status, :message => e }
        end

        if( node == nil )
          e = 'missing node'
          logger.error( e )
          logger.error( data )
          return { :status  => status, :message => e }
        end

        if( payload == nil )
          e = 'missing payload'
          logger.error( e )
          logger.error( data )
          return { :status  => status, :message => e }
        end

      end

      if( payload.is_a?( String ) == true && payload.to_s != '' )
        payload  = JSON.parse( payload )
      end

      logger.debug( JSON.pretty_generate( payload ) )

      timestamp  = payload.dig('timestamp')
      config     = payload.dig('config')
#      fqdn       = payload.dig('fqdn') || node
      dns        = payload.dig('dns')

      unless( !dns.nil? )
        ip    = dns.dig('ip')
        short = dns.dig('short')
        fqdn  = dns.dig('fqdn')
      end

      logger.info( sprintf( 'send notification for node \'%s\'', fqdn ) )

    end


    def send_message( data )

      logger.debug( JSON.pretty_generate( data ) )

      job = {
        cmd:  'information',
        from: 'graphite',
        payload: data
      }.to_json

      result = @mq_producer.addJob( queue, job, 1, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end


  end

end

