
module Icinga

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

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

        case command
        when 'add'
          logger.info( sprintf( 'add node %s', node ) )
          result = self.addHost( { :host => node, :vars => payload } )

          logger.info( result )
        when 'remove'
          logger.info( sprintf( 'remove checks for node %s', node ) )
          result = self.deleteHost( { :host => node } )

          logger.info( result )
        when 'info'
          logger.info( sprintf( 'give information for node %s', node ) )
          result = self.listHost( { :host => node } )
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
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

      logger.debug( JSON.pretty_generate( data ) )

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
