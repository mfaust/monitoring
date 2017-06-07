
class CMIcinga2 < Icinga2::Client

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue()

#       logger.debug( "CMIcinga2::Queue.queue()" )
      data = @mqConsumer.getJobFromTube( @mqQueue )

      if( data.count() != 0 )

        stats = @mqConsumer.tubeStatistics( @mqQueue )
        logger.debug( {
          :total   => stats.dig(:total),
          :ready   => stats.dig(:ready),
          :delayed => stats.dig(:delayed),
          :buried  => stats.dig(:buried)
        } )

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

      command     = data.dig( :body, 'cmd' )
      node        = data.dig( :body, 'node' )
      payload     = data.dig( :body, 'payload' )
      @identifier = nil

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

      ip, short, fqdn = self.nsLookup( node )

      if( @jobs.jobs( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } ) == true )

        logger.warn( 'we are working on this job' )

        return {
          :status  => 409, # 409 Conflict
          :message => 'we are working on this job'
        }
      end

#       logger.debug( payload )
#       logger.debug( payload.class.to_s )
#
#       if( payload.is_a?( String ) == true && payload.to_s != '' )
#         payload  = JSON.parse( payload )
#       end
#
#       logger.debug( payload )
#       logger.debug( payload.class.to_s )
#
#       config     = payload.dig('config')
#
#       if( config != nil )
#
#         if( config.is_a?( String ) == true && config.to_s != '' )
#           config  = JSON.parse( config )
#         end
#
#         @identifier = config.dig('graphite-identifier')
#       end

      @jobs.add( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )


      # add Node
      #
      if( command == 'add' )

        logger.info( sprintf( 'add node %s', node ) )
#        logger.debug( payload )
#        payload = JSON.parse( payload )

        services   = self.nodeInformation( { :ip => ip, :host => short, :fqdn => fqdn } )

        # TODO: add groups
        #
        if( ! services.empty? )
          payload = services
        else
          payload = {}
        end

        logger.debug( payload )

#         if( @icingaCluster == true && @icingaSatellite != nil )
#           payload['attrs']['zone'] = @icingaSatellite
#         end

        # TODO
        # full API support
        result = self.addHost( { :name => node, :fqdn => fqdn, :enable_notifications => @icingaNotifications, :vars => payload } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status => 200
        }

      # remove Node
      #
      elsif( command == 'remove' )

        logger.info( sprintf( 'remove checks for node %s', node ) )

        result = self.deleteHost( { :name => node } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status => 200
        }

      # information about Node
      #
      elsif( command == 'info' )

        logger.info( sprintf( 'give information for node %s', node ) )

        result = self.listHost( { :name => node } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status => 200
        }

      # all others
      #
      else

        logger.error( sprintf( 'wrong command detected: %s', command ) )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

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

      command = params.dig(:cmd)
      node    = params.dig(:node)
      queue   = params.dig(:queue)
      data    = params.dig(:payload)
      prio    = params.dig(:prio)  || 65536
      ttr     = params.dig(:ttr)   || 10
      delay   = params.dig(:delay) || 2

      job = {
        cmd:  command,      # require
        node: node,         # require
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ), # optional
        from: 'icinga',     # optional
        payload: data       # require
      }.to_json

      result = @mqProducer.addJob( queue, job, prio, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end


  end

end
