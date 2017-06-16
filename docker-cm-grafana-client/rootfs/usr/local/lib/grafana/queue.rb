
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

      logger.debug( sprintf( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

      command  = data.dig( :body, 'cmd' )
      node     = data.dig( :body, 'node' )
      payload  = data.dig( :body, 'payload' )
      tags     = []
      overview = true

      logger.debug( payload )

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

        tags     = payload.dig('tags')
        overview = payload.dig('overview') || true
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

      # no DNS data?
      #
      if( ip == nil && short == nil && fqdn == nil )

        logger.warn( 'we found no dns data!' )

        # ask grafana
        #
        result = self.listDashboards( { :host => node } )

        logger.debug( result )

        return {
          :status  => 500,
          :message => 'no dns data found'
        }
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

      # add Node
      #
      if( command == 'add' )

        # TODO
        # check payload!
        # e.g. for 'force' ...
        result = self.createDashboardForHost( { :host => node, :tags => tags, :overview => overview } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status  => 200,
          :message => result
        }

      # remove Node
      #
      elsif( command == 'remove' )

#         logger.info( sprintf( 'remove dashboards for node %s', node ) )
        result = self.deleteDashboards( { :ip => ip, :host => node, :fqdn => fqdn } )

        logger.info( result )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status  => 200,
          :message => result
        }

      # information about Node
      #
      elsif( command == 'info' )

#         logger.info( sprintf( 'give dashboards for %s back', node ) )
        result = self.listDashboards( { :host => node } )

        self.sendMessage( { :cmd => 'info', :host => node, :queue => 'mq-grafana-info', :payload => result, :ttr => 1, :delay => 0 } )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status  => 200,
          :message => result
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

#      result[:request]    = data
#      logger.info( result )
#      logger.debug( '--------------------------------------------------------' )

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
        from: 'grafana',    # optional
        payload: data       # require
      }.to_json

      result = @mqProducer.addJob( queue, job, prio, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end

  end

end
