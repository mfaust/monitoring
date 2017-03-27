
module Grafana

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

      data = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        jobId  = data.dig( :id )

        result = self.processQueue( data )

        logger.debug( result )
        logger.debug( result.class.to_s )

        status = result.dig(:status).to_i

        if( status == 200 || status == 500 )

          @mqConsumer.deleteJob( @mqQueue, jobId )
        else

          @mqConsumer.buryJob( @mqQueue, jobId )
        end
      end


#      c = MessageQueue::Consumer.new( @MQSettings )
#      processQueue(
#        c.getJobFromTube( @mqQueue )
#      )

    end


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.debug( '--------------------------------------------------------' )
        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )
        logger.debug( data )

        command  = data.dig( :body, 'cmd' )     || nil
        node     = data.dig( :body, 'node' )    || nil
        payload  = data.dig( :body, 'payload' ) || nil
        tags     = []
        overview = true

#         logger.debug( payload )

        if( command == nil )
          logger.error( 'wrong command' )
          logger.error( data )

          return {
            :status  => 500,
            :message => sprintf( 'wrong command detected: %s', command )
          }
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )

          return {
            :status  => 500,
            :message => 'missing node or payload'
          }
        end

        if( payload.is_a?( String ) == true && payload.to_s != '' )

          payload  = JSON.parse( payload )
        end

        if( payload.is_a?( String ) == false )

          tags     = payload.dig( 'tags' )
          overview = payload.dig( 'overview' ) || true
        end

        case command
        when 'add'
#           logger.info( sprintf( 'add dashboards for node %s', node ) )

          # {:id=>"9", :tube=>"mq-grafana", :state=>"reserved", :ttr=>10, :prio=>65536, :age=>3, :delay=>2, :body=>{"cmd"=>"add", "node"=>"monitoring-16-01", "timestamp"=>"2017-01-14 19:05:41", "from"=>"rest-service", "payload"=>""}}

          # TODO
          # check payload!
          # e.g. for 'force' ...
          result = self.createDashboardForHost( { :host => node, :tags => tags, :overview => overview } )

          logger.info( result )

          return {
            :status  => 200
          }

        when 'remove'
#           logger.info( sprintf( 'remove dashboards for node %s', node ) )
          result = self.deleteDashboards( { :host => node } )

          logger.info( result )

          return {
            :status  => 200
          }

        when 'info'

          logger.info( sprintf( 'give dashboards for %s back', node ) )
          result = self.listDashboards( { :host => node } )

          self.sendMessage( { :cmd => 'info', :queue => 'mq-grafana-info', :payload => result, :ttr => 1, :delay => 0 } )

          return {
            :status  => 200
          }
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          return {
            :status  => 500,
            :message => sprintf( 'wrong command detected: %s', command )
          }
        end

#        result[:request]    = data
#        logger.info( result )
#        logger.debug( '--------------------------------------------------------' )
      end

    end


    def sendMessage( params = {} )

      cmd     = params.dig(:cmd)
      node    = params.dig(:node)
      queue   = params.dig(:queue)
      payload = params.dig(:payload) || {}
      ttr     = params.dig(:ttr)     || 10
      delay   = params.dig(:delay)   || 2

      if( cmd == nil || queue == nil || payload.count() == 0 )
        return
      end

#       logger.debug( JSON.pretty_generate( payload ) )

      p = MessageQueue::Producer.new( @MQSettings )

      job = {
        cmd:  cmd,          # require
        node: node,         # require
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
        from: 'grafana',    # optional
        payload: payload    # require
      }.to_json

      result = p.addJob( queue, job, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end

  end

end
