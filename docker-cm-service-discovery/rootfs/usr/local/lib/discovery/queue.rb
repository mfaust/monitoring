
module ServiceDiscovery

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

        if( result.dig(:status).to_i == 200 )

          @mqConsumer.deleteJob( @mqQueue, jobId )
        else

          @mqConsumer.buryJob( @mqQueue, jobId )
        end
      end

    end


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )
        logger.debug( data )

        command = data.dig( :body, 'cmd' )     || nil
        node    = data.dig( :body, 'node' )    || nil
        payload = data.dig( :body, 'payload' ) || nil

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

        case command
        when 'add'
          logger.info( sprintf( 'add node %s', node ) )

          begin
            # TODO
            # check payload!
            # e.g. for 'force' ...
            result = self.addHost( node, payload )

            @db.setStatus( { :ip => node, :short => node, :status => isRunning?( node ) } )

#             logger.debug( result )
          rescue

          end
        when 'remove'
          logger.info( sprintf( 'remove node \'%s\'', node ) )

          # check first for existing node!
          result = @db.nodes( { :ip => node, :short => node } )

          nodeExists = result.count != 0 ? true : false

          if( nodeExists == false )

            logger.info( 'node not in monitoring! skipping delete' )

            return {
              :status  => 200,
              :message => sprintf( 'node are not in database found. skipping delete ...' )
            }

          end

          begin

#             logger.debug('1')
            self.sendMessage( { :cmd => command, :queue => 'mq-collector', :payload => { :host => node, :pre => 'prepare' }, :ttr => 1, :delay => 0 } )

#             logger.debug('2')
            @db.setStatus( { :ip => node, :short => node, :status => 98 } )

#             logger.debug('3')
            result = self.deleteHost( node )

#             logger.debug('4')
#             logger.debug( result )

          rescue => e

            logger.error( e )

          end

        when 'refresh'
          logger.info( sprintf( 'refresh node %s', node ) )

          result = self.refreshHost( node )

#           logger.debug( result )

        when 'info'
          logger.info( sprintf( 'give information for %s back', node ) )

          result = @db.nodes( { :ip => node, :short => node } )

          nodeExists = result.count != 0 ? true : false

          if( nodeExists == false )

            logger.info( 'node are not in database found' )

            self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => {}, :ttr => 1, :delay => 0 } )

            return {
              :status  => 200,
              :message => sprintf( 'node are not in database found' )
            }

          end

          result = self.listHosts( node )

          logger.debug( result )

          self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => result, :ttr => 1, :delay => 0 } )

          return {
            :status  => 200,
            :message => 'information succesful send'
          }

        else
  #         logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }

#           logger.debug( result )
        end

        logger.debug( result )

        return result

  #       result[:request]    = data

  #       logger.debug( 'send message to \'mq-discover-info\'' )
  #       self.sendMessage( { :cmd => 'info', :queue => 'mq-discovery-info', :payload => result } )

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

      p = MessageQueue::Producer.new( @MQSettings )

      job = {
        cmd:  cmd,          # require
        node: node,         # require
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
        from: 'discovery',  # optional
        payload: payload    # require
      }.to_json

      result = p.addJob( queue, job, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end

  end

end

