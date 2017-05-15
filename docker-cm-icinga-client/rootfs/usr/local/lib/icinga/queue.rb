
module Icinga

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

      data = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        stats = @mqConsumer.tubeStatistics( @mqQueue )
        logger.debug( { :total => stats.dig(:total), :ready => stats.dig(:ready), :delayed => stats.dig(:delayed), :buried => stats.dig(:buried) } )

        jobId  = data.dig( :id )

        result = self.processQueue( data )

        status = result.dig(:status).to_i

        if( status == 200 || status == 409 || status == 500 || status == 503 )

          @mqConsumer.deleteJob( @mqQueue, jobId )
        else

          @mqConsumer.buryJob( @mqQueue, jobId )
        end
      end

    end


    def processQueue( data = {} )

      logger.info( sprintf( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

      command = data.dig( :body, 'cmd' )
      node    = data.dig( :body, 'node' )
      payload = data.dig( :body, 'payload' )

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

      logger.debug( sprintf( '  command: %s', command ) )
      logger.info( sprintf( '  node %s', node ) )


      # add Node
      #
      if( command == 'add' )

        logger.info( sprintf( 'add node %s', node ) )

        result = self.addHost( { :host => node, :vars => payload } )

        logger.info( result )

        return {
          :status => 200
        }

      # remove Node
      #
      elsif( command == 'remove' )

        logger.info( sprintf( 'remove checks for node %s', node ) )

        result = self.deleteHost( { :host => node } )

        logger.info( result )

        return {
          :status => 200
        }

      # information about Node
      #
      elsif( command == 'info' )

        logger.info( sprintf( 'give information for node %s', node ) )

        result = self.listHost( { :host => node } )

        logger.info( result )

        return {
          :status => 200
        }

      # all others
      #
      else

        logger.error( sprintf( 'wrong command detected: %s', command ) )

        return {
          :status  => 500,
          :message => sprintf( 'wrong command detected: %s', command )
        }

      end

      if( result.is_a?( String ) )

        result = JSON.parse( result )
      end

      result[:request]    = data

#       logger.debug( result )

#         self.sendMessage( result )

    end


    def sendMessage( params = {} )

      cmd     = params.dig(:cmd)     || 'information'
      node    = params.dig(:node)
      queue   = params.dig(:queue)   || 'mq-icinga'
      payload = params.dig(:payload) || {}
      ttr     = params.dig(:ttr)     || 10
      delay   = params.dig(:delay)   || 2

      if( cmd == nil || queue == nil || payload.count() == 0 )
        return
      end

      job = {
        cmd:  cmd,          # require
        node: node,         # require
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
        from: 'icinga',     # optional
        payload: payload    # require
      }.to_json

      result = @mqProducer.addJob( queue, job, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end


  end

end
