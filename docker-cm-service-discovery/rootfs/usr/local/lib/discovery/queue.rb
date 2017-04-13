
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
        logger.debug( data )

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

          # TODO
          # check payload!
          # e.g. for 'force' ...
          result = self.addHost( node, payload )

          status  = result.dig(:status)
          message = result.dig(:message)

          logger.debug( result )

          if( status.to_i == 200 )

            @redis.setStatus( { :short => node, :status => Storage::RedisClient::ONLINE } )
          end

# 
#           # BUG
#           # Use DNS entry and take the IP to check isAlive!
#           dns      = @redis.dnsData( { :short => node } )
#
#           logger.debug( dns )
#           ip = dns.dig(:ip) || dns.dig('ip')
#
#           networkStatus = Utils::Network.isRunning?( ip )
#
#           @redis.setStatus( { :short => node, :status => networkStatus } )

          return {
            :status  => status,
            :message => message
          }

        when 'remove'
          logger.info( sprintf( 'remove node \'%s\'', node ) )

          # check first for existing node!
          #
          result = @redis.nodes( { :short => node } )
#
#           logger.debug( result.class.to_s )
#           logger.debug( result )
#
#           nodeExists = result.count != 0 ? true : false

          if( result.to_s != node.to_s )

            logger.info( 'node not in monitoring! skipping delete' )

            return {
              :status  => 200,
              :message => sprintf( 'node are not in database found. skipping delete ...' )
            }

          end

          begin

            self.sendMessage( { :cmd => command, :queue => 'mq-collector', :payload => { :host => node, :pre => 'prepare' }, :ttr => 1, :delay => 0 } )

            @redis.setStatus( { :short => node, :status => Storage::RedisClient::DELETE } )

            result = self.deleteHost( node )

          rescue => e

            logger.error( e )

          end

          return {
            :status => 200
          }

        when 'refresh'
          logger.info( sprintf( 'refresh node %s', node ) )

          result = self.refreshHost( node )

            return {
              :status  => 200,
              :message => result
            }

        when 'info'
          logger.info( sprintf( 'give information for %s back', node ) )

          result = @redis.nodes( { :short => node } )

#           nodeExists = result.count != 0 ? true : false

          if( result.to_s != node.to_s )

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
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 500,
            :message => sprintf( 'wrong command detected: %s', command )
          }

        end

        if( result.is_a?( String ) )

          result = JSON.parse( result )
        end

        result[:request]    = data

        logger.debug( result )

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

