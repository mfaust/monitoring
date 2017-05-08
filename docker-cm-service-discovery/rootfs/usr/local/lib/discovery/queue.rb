
module ServiceDiscovery

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

          # TODO
          # check payload!
          # e.g. for 'force' ...
          result  = self.addHost( node, payload )

          status  = result.dig(:status)
          message = result.dig(:message)

          result = {
            :status  => status,
            :message => message
          }

          logger.debug( result )

          return result

        # remove Node
        #
        elsif( command == 'remove' )

          # check first for existing node!
          #
          result = @redis.nodes( { :short => node } )

          logger.debug( "redis: '#{result}' | node: '#{node}'" )

          if( result.to_s != node.to_s )

            logger.info( 'node not in monitoring. skipping delete' )

            return {
              :status  => 200,
              :message => sprintf( 'node not in monitoring. skipping delete ...' )
            }

          end

          begin

            # remove node also from data-collector!
            #
            self.sendMessage( { :cmd => command, :queue => 'mq-collector', :payload => { :host => node, :pre => 'prepare' }, :ttr => 1, :delay => 0 } )

            result = self.deleteHost( node )

          rescue => e

            logger.error( e )

          end

          return {
            :status => 200
          }

        # refresh Node
        #
        elsif( command == 'refresh' )

          result = self.refreshHost( node )

            return {
              :status  => 200,
              :message => result
            }

        # information about Node
        #
        elsif( command == 'info' )

          result = @redis.nodes( { :short => node } )

          logger.debug( "redis: '#{result}' | node: '#{node}'" )

          if( result.to_s != node.to_s )

            logger.info( 'node not in monitoring. skipping info' )

            return {
              :status  => 200,
              :message => sprintf( 'node not in monitoring. skipping info ...' )
            }

          end

#           self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => {}, :ttr => 1, :delay => 0 } )
#
#           return {
#             :status  => 200
#           }

          result = self.listHosts( node )

          status  = result.dig(:status)
          message = result.dig(:message)

          r = {
            :status  => status,
            :message => message
          }

          logger.debug( r )

          self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => result, :ttr => 1, :delay => 0 } )

          return {
            :status  => 200,
            :message => 'information succesful send'
          }

        # all others
        #
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

#        logger.debug( result )

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

      job = {
        cmd:  cmd,          # require
        node: node,         # require
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
        from: 'discovery',  # optional
        payload: payload    # require
      }.to_json

      result = @mqProducer.addJob( queue, job, ttr, delay )

#       logger.debug( job )
#       logger.debug( result )

    end

  end

end

