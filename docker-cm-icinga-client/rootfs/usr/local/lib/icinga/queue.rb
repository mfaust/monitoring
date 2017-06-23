
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

        if( stats.dig(:ready).to_i > 10 )
          logger.warn( 'more then 10 jobs in queue ... just wait' )

          @mqConsumer.cleanQueue( @mqQueue )
          return
        end

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

      if( payload.is_a?( String ) == true && payload.to_s != '' )
        payload  = JSON.parse( payload )
      end

      logger.debug( JSON.pretty_generate( payload ) )

      if( payload.is_a?( String ) == false )
        dns      = payload.dig('dns')
      end

      logger.info( sprintf( '  %s node %s', command , node ) )

      if !dns.nil?
        ip    = dns.dig('ip')
        short = dns.dig('short')
        fqdn  = dns.dig('fqdn')
      else
        ip, short, fqdn = self.nsLookup( node )
      end

      if( @jobs.jobs( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } ) == true )

        logger.warn( 'we are working on this job' )

        return {
          :status  => 409, # 409 Conflict
          :message => 'we are working on this job'
        }
      end

      @jobs.add( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

      @cache.set( format( 'dns-%s', node ) , expiresIn: 320 ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }

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
#         @identifier = config.dig('graphite_identifier')
#       end

      # add Node
      #
      if( command == 'add' )

        logger.info( sprintf( 'add node %s', node ) )
#        logger.debug( payload )
#        payload = JSON.parse( payload )

        services     = self.nodeInformation( { :ip => ip, :host => short, :fqdn => fqdn } )
        display_name = @database.config( { :ip => ip, :short => short, :fqdn => fqdn, :key => 'display_name' } )

        logger.debug( display_name )
        logger.debug( display_name.class.to_s )

        if( display_name.nil? )
          display_name = fqdn
        else
          display_name = display_name.dig('display_name') || fqdn
        end

        # TODO: add groups
        #
        if( ! services.empty? )
          payload = services
        else
          payload = {}
        end


        # TODO
        # full API support
        params = {
          :host => fqdn,
          :fqdn => fqdn,
          :display_name => display_name,
          :enable_notifications => @icingaNotifications,
          :vars => payload
        }

        logger.debug(params)

        result = self.add_host(params)

        status = result.dig(:status)

        if( status != 200 )
          logger.error( result )
        end

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status => status
        }

      # remove Node
      #
      elsif( command == 'remove' )

        logger.info( sprintf( 'remove checks for node %s', node ) )

        result = self.delete_host( { :host => fqdn, :fqdn => fqdn } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status => 200
        }

      # information about Node
      #
      elsif( command == 'info' )

        logger.info( sprintf( 'give information for node %s', node ) )

        result = self.hosts( { :host => fqdn } )

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
