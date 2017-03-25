
module Grafana

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

#       logger.debug('queue()')

      c = MessageQueue::Consumer.new( @MQSettings )

      processQueue(
        c.getJobFromTube( @mqQueue )
      )

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
          return
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )
          return
        end

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

#         logger.debug( payload )
#         logger.debug( payload.class.to_s )

        if( payload.is_a?( String ) == true && payload.to_s != '' )

          payload  = JSON.parse( payload )
        end

#         logger.debug( payload )
#         logger.debug( payload.class.to_s )

        if( payload.is_a?( String ) == false )

          tags     = payload.dig( 'tags' )
          overview = payload.dig( 'overview' ) || true

#           logger.debug( tags )
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
        when 'remove'
#           logger.info( sprintf( 'remove dashboards for node %s', node ) )
          result = self.deleteDashboards( { :host => node } )

          logger.info( result )
        when 'info'
#           logger.info( sprintf( 'give dashboards for %s back', node ) )
          result = self.listDashboards( { :host => node } )

          self.sendMessage( { :cmd => 'info', :queue => 'mq-grafana-info', :payload => result, :ttr => 1, :delay => 0 } )
#           self.sendMessage( result )

          return
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }
        end

        result[:request]    = data

        logger.info( result )

        logger.debug( '--------------------------------------------------------' )
      end

    end


    def sendMessage( data = {} )

      cmd     = params[:cmd]     ? params[:cmd]     : nil
      node    = params[:node]    ? params[:node]    : nil
      queue   = params[:queue]   ? params[:queue]   : nil
      payload = params[:payload] ? params[:payload] : {}
      ttr     = params[:ttr]     ? params[:trr]     : 10
      delay   = params[:delay]   ? params[:delay]   : 2

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

      logger.debug( JSON.pretty_generate( job ) )

      logger.debug( p.addJob( queue, job, ttr, delay ) )

    end

  end

end
