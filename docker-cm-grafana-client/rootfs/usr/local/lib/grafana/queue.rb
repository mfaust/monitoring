
module Grafana

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

      if( @loggedIn == false )

        logger.debug( 'client are not logged in, skip' )
        return
      end

      session = self.ping_session()
      msg     = session.dig('message')

      if( msg != nil && msg != 'Logged in' )

        logger.debug( 'client are not logged in, skip' )
        return
      end

      data    = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        stats = @mqConsumer.tubeStatistics( @mqQueue )
        logger.debug( { :total => stats.dig(:total), :ready => stats.dig(:ready), :delayed => stats.dig(:delayed), :buried => stats.dig(:buried) } )

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

      logger.debug( sprintf( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

      command  = data.dig( :body, 'cmd' )
      node     = data.dig( :body, 'node' )
      payload  = data.dig( :body, 'payload' )
      tags     = []
      overview = true

#       logger.debug( payload )

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

      if( payload.is_a?( String ) == false )

        tags     = payload.dig( 'tags' )
        overview = payload.dig( 'overview' ) || true
      end

      logger.debug( sprintf( '  command: %s', command ) )
      logger.info( sprintf( '  node %s', node ) )

      # add Node
      #
      if( command == 'add' )

        # TODO
        # check payload!
        # e.g. for 'force' ...
        result = self.createDashboardForHost( { :host => node, :tags => tags, :overview => overview } )

        logger.info( result )

        return {
          :status  => 200,
          :message => result
        }

      # remove Node
      #
      elsif( command == 'remove' )

#         logger.info( sprintf( 'remove dashboards for node %s', node ) )
        result = self.deleteDashboards( { :host => node } )

        logger.info( result )

        return {
          :status  => 200,
          :message => result
        }

      # information about Node
      #
      elsif( command == 'info' )

#         logger.info( sprintf( 'give dashboards for %s back', node ) )
        result = self.listDashboards( { :host => node } )

        self.sendMessage( { :cmd => 'info', :queue => 'mq-grafana-info', :payload => result, :ttr => 1, :delay => 0 } )

        return {
          :status  => 200,
          :message => result
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

#      result[:request]    = data
#      logger.info( result )
#      logger.debug( '--------------------------------------------------------' )

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
        from: 'grafana',    # optional
        payload: payload    # require
      }.to_json

      result = @mqProducer.addJob( queue, job, ttr, delay )

    end

  end

end
