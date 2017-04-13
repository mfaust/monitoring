
module Graphite

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

      data = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        logger.debug( data )

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

        @timestamp = nil

        command    = data.dig( :body, 'cmd' )     || nil
        node       = data.dig( :body, 'node' )    || nil
        payload    = data.dig( :body, 'payload' ) || nil

        if( command == nil )
          logger.error( 'wrong command' )
          logger.error( data )

          return {
            :status  => 500,
            :message => 'no command given',
            :request => data
          }
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )

          return {
            :status  => 500,
            :message => 'missing node or payload',
            :request => data
          }
        end

        timestamp  = payload.dig( 'timestamp' )

        if( timestamp != nil )

          if( timestamp.is_a?( Time ) )

            @timestamp = Time.parse( timestamp )

            logger.debug( @timestamp )
          end

          @timestamp = timestamp.to_i
        end

        logger.info( sprintf( 'add annotation \'%s\' for node %s', command, node ) )

        case command
        when 'create', 'remove'

          result = self.nodeAnnotation( node, command )

          logger.info( result )

          return {
            :status => 200
          }

        when 'loadtest'

          argument = payload.dig( 'argument' )

          if( argument != 'start' && argument != 'stop' )
            logger.error( sprintf( 'wrong argument for LOADTEST \'%s\'', argument ) )

            return {
              :status  => 500,
              :message => sprintf( 'wrong argument for LOADTEST \'%s\'', argument )
            }
          end

          result = self.loadtestAnnotation( node, argument )

          logger.info( result )

          return {
            :status => 200
          }

        when 'deployment'

          message = payload.dig( 'message' )
          tags    = payload.dig( 'tags' ) || []

          result = self.deploymentAnnotation( node, message, tags )

          logger.info( result )

          return {
            :status => 200
          }

        when 'general'

          description = payload.dig( 'description' )
          message     = payload.dig( 'message' )
          tags        = payload.dig( 'tags' ) || []

          result = self.generalAnnotation( node, description, message, tags )

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

        end

        result[:request]    = data

#         self.sendMessage( result )
      end

      return {
        :status  => 500,
        :message => 'no data found'
      }

    end


    def sendMessage( data = {} )

      logger.debug( JSON.pretty_generate( data ) )

      p = MessageQueue::Producer.new( @MQSettings )

      job = {
        cmd:  'information',
        from: 'graphite',
        payload: data
      }.to_json

      result = p.addJob( queue, job, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end


  end

end
