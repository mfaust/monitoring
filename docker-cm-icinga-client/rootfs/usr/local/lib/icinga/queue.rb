
module Icinga

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

    end


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )
#         logger.debug( data )
#         logger.debug( JSON.pretty_generate( data.dig( :body, 'payload' ) ) )

        command = data.dig( :body, 'cmd' )     || nil
        node    = data.dig( :body, 'node' )    || nil
        payload = data.dig( :body, 'payload' ) || nil

        if( command == nil )
          logger.error( 'wrong command' )
          logger.error( data )

          return {
            :status  => 500,
            :message => 'no command given'
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


        case command
        when 'add'
          logger.info( sprintf( 'add node %s', node ) )

          result = self.addHost( { :host => node, :vars => payload } )

          logger.info( result )

          return {
            :status => 200
          }
        when 'remove'
          logger.info( sprintf( 'remove checks for node %s', node ) )

          result = self.deleteHost( { :host => node } )

          logger.info( result )

          return {
            :status => 200
          }
        when 'info'
          logger.info( sprintf( 'give information for node %s', node ) )

          result = self.listHost( { :host => node } )

          logger.info( result )

          return {
            :status => 200
          }
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          return {
            :status  => 500,
            :message => sprintf( 'wrong command detected: %s', command )
          }

#          logger.info( result )
        end

        if( result.is_a?( String ) )

          result = JSON.parse( result )
        end

        result[:request]    = data

        logger.debug( result )

#         self.sendMessage( result )
      end

    end


    def sendMessage( data = {} )

#       logger.debug( JSON.pretty_generate( data ) )

      p = MessageQueue::Producer.new( @MQSettings )

      job = {
        cmd:  'information',
        from: 'icinga',
        payload: data
      }.to_json

      logger.debug( p.addJob( 'mq-icinga', job ) )

    end


  end

end
