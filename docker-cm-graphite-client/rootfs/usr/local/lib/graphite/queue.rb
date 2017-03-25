
module Graphite

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

        @timestamp = nil

        command    = data.dig( :body, 'cmd' )     || nil
        node       = data.dig( :body, 'node' )    || nil
        payload    = data.dig( :body, 'payload' ) || nil
        timestamp  = payload.dig( 'timestamp' )
#         logger.debug( timestamp )

        if( timestamp != nil )

          if( timestamp.is_a?( Time ) )

#             logger.debug( 'is Time' )
            timestamp = Time.parse( timestamp )

            logger.debug( @timestamp )
          end

          @timestamp = timestamp.to_i

#           logger.debug( @timestamp )
        end

        if( command == nil )
          logger.error( 'no command' )
          logger.error( data )

          return {
            :status  => 400,
            :message => 'no command',
            :request => data
          }
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )

          return {
            :status  => 400,
            :message => 'missing node or payload',
            :request => data
          }
        end

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }

        logger.info( sprintf( 'add annotation \'%s\' for node %s', command, node ) )

        case command
        when 'create', 'remove'

          result = self.nodeAnnotation( node, command )

          logger.info( result )
        when 'loadtest'

          argument = payload.dig( 'argument' )

          if( argument != 'start' || argument != 'stop' )
            logger.error( sprintf( 'wrong argument for LOADTEST \'%s\'', argument ) )
            return
          end

          result = self.loadtestAnnotation( node, argument )

          logger.info( result )

        when 'deployment'

          message = payload.dig( 'message' )
          tags    = payload.dig( 'tags' ) || []

          result = self.deploymentAnnotation( node, message, tags )

          logger.info( result )
        when 'general'

          description = payload.dig( 'description' )
          message     = payload.dig( 'message' )
          tags        = payload.dig( 'tags' ) || []

          result = self.generalAnnotation( node, description, message, tags )

          logger.info( result )
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }

          logger.info( result )
        end

        result[:request]    = data

#         self.sendMessage( result )
      end

    end


    def sendMessage( data = {} )

      logger.debug( JSON.pretty_generate( data ) )

      p = MessageQueue::Producer.new( @MQSettings )

      job = {
        cmd:  'information',
        from: 'graphite',
        payload: data
      }.to_json

      logger.debug( p.addJob( 'mq-information', job ) )

    end


  end

end
