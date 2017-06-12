
module Graphite

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

      data = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        stats = @mqConsumer.tubeStatistics( @mqQueue )
        logger.debug( {
          :total   => stats.dig(:total),
          :ready   => stats.dig(:ready),
          :delayed => stats.dig(:delayed),
          :buried  => stats.dig(:buried)
        } )

        if( stats.dig(:ready).to_i > 10 )
          logger.warn( 'more then 10 jobs in queue ... just wait' )

          @mqConsumer.cleanQueue( @mqQueue )
          return
        end

        jobId  = data.dig( :id )

        result = self.processQueue( data )

        status = result.dig(:status).to_i

        if( status == 200 || status == 500 )

          @mqConsumer.deleteJob( @mqQueue, jobId )
        else

          @mqConsumer.buryJob( @mqQueue, jobId )
        end
      end

    end


    def processQueue( data = {} )


      logger.info( sprintf( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

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
      fqdn       = payload.dig('fqdn') || node

      @identifier = fqdn


      if( timestamp != nil )

        if( timestamp.is_a?( Time ) )

          @timestamp = Time.parse( timestamp )

          logger.debug( @timestamp )
        end

        @timestamp = timestamp.to_i
      end

      if( config != nil )

        if( config.is_a?( String ) == true && config.to_s != '' )

          config  = JSON.parse( config )
        end

        @identifier = config.dig('graphite-identifier')
      end

      logger.debug( JSON.pretty_generate( payload ) )


      logger.info( sprintf( 'add annotation \'%s\' for node \'%s\'', command, fqdn ) )

      case command
      when 'create', 'remove'

        result = self.nodeAnnotation( fqdn, command )

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

        result = self.loadtestAnnotation( fqdn, argument )

        logger.info( result )

        return {
          :status => 200
        }

      when 'deployment'

        message = payload.dig( 'message' )
        tags    = payload.dig( 'tags' ) || []

        result = self.deploymentAnnotation( fqdn, message, tags )

        logger.info( result )

        return {
          :status => 200
        }

      when 'general'

        description = payload.dig( 'description' )
        message     = payload.dig( 'message' )
        tags        = payload.dig( 'tags' ) || []

        result = self.generalAnnotation( fqdn, description, message, tags )

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

    end


    def sendMessage( data = {} )

      logger.debug( JSON.pretty_generate( data ) )

      job = {
        cmd:  'information',
        from: 'graphite',
        payload: data
      }.to_json

      result = @mqProducer.addJob( queue, job, 1, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end


  end

end
