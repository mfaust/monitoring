
class CMGrafana < Grafana::Client

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue

      if(!@logged_in)

        logger.debug( 'client are not logged in, skip' )
        return
      end

#       msg     = nil
#       session = self.ping_session
#       msg     = session.dig('message') unless( session.is_a?(TrueClass) )
#
#       if( msg != nil && msg != 'Logged in' )
#         logger.debug( 'client are not logged in, skip' )
#         return
#       end

      data    = @mq_consumer.getJobFromTube( @mq_queue )

      if( data.count != 0 )

        stats = @mq_consumer.tubeStatistics( @mq_queue )
        logger.debug( {
          :total   => stats.dig(:total),
          :ready   => stats.dig(:ready),
          :delayed => stats.dig(:delayed),
          :buried  => stats.dig(:buried)
        } )

        if( stats.dig(:ready).to_i > 10 )
          logger.warn( 'more then 10 jobs in queue ... just wait' )

          @mq_consumer.cleanQueue( @mq_queue )
          return
        end

        job_id  = data.dig( :id )

        result = self.process_queue(data )

        status = result.dig(:status).to_i

        if( status == 200 || status == 409 || status == 500 || status == 503 )

          @mq_consumer.deleteJob( @mq_queue, job_id )
        else

          @mq_consumer.buryJob( @mq_queue, job_id )
        end
      end

    end


    def process_queue(data = {} )

      logger.debug( format( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )

      command  = data.dig( :body, 'cmd' )
      node     = data.dig( :body, 'node' )
      payload  = data.dig( :body, 'payload' )
      tags     = []
      overview = true
      dns = nil

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

      if(!payload.is_a?(String))

        tags     = payload.dig('tags')
        overview = payload.dig('overview') || true
        dns      = payload.dig('dns')
      end

      logger.info( format( '%s node %s', command , node ) )

      if( dns.nil? )
        ip, short, fqdn = self.ns_lookup(node)
      else
        ip = dns.dig('ip')
        short = dns.dig('short')
        fqdn = dns.dig('fqdn')
      end

      # no DNS data?
      #
      if( ip == nil && short == nil && fqdn == nil )

        logger.warn( 'we found no dns data!' )

        # ask grafana
        #
        result = self.list_dashboards({:host => node } )

        logger.debug( result )

        return {
          :status  => 500,
          :message => 'no dns data found'
        }
      end

      job_option = { command: command, ip: ip, short: short, fqdn: fqdn }


      if( @jobs.jobs( job_option ) )

        logger.warn( 'we are working on this job' )

        return {
          :status  => 409, # 409 Conflict
          :message => 'we are working on this job'
        }
      end

      @jobs.add( job_option )

      @cache.set(format( 'dns-%s', node ) , expires_in: 320 ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }

      # add Node
      #
      if( command == 'add' )

        # TODO
        # check payload!
        # e.g. for 'force' ...
        result = self.create_dashboard_for_host( host: node, tags: tags, overview: overview )

        logger.debug( result )

        @jobs.del( job_option )

        return { status: 200, message: result }
      end

      # remove Node
      #
      if( command == 'remove' )

#         logger.info( format( 'remove dashboards for node %s', node ) )
        result = self.delete_dashboards( ip: ip, host: node, fqdn: fqdn )

        logger.debug( result )

        @jobs.del( job_option )

        return { status: 200, message: result }
      end

      # information about Node
      #
      if( command == 'info' )

#         logger.info( format( 'give dashboards for %s back', node ) )
        result = self.list_dashboards( host: node )

        self.send_message( cmd: 'info', host: node, queue: 'mq-grafana-info', payload: result, ttr: 1, delay: 0 )

        @jobs.del( job_option )

        return { status: 200, message: result }
      end

      #
      #
      if( command == 'update' )

        result = update_dashboards( host: node )

        logger.debug( result )

        @jobs.del( job_option )

        return { status: 200, message: result }
      end

      # all others
      #
      logger.error( format( 'wrong command detected: %s', command ) )

      @jobs.del( job_option )

      return { status: 500, message: format( 'wrong command detected: %s', command ) }

#      result[:request]    = data
#      logger.info( result )
#      logger.debug( '--------------------------------------------------------' )

    end


    def send_message(params = {} )

      command = params.dig(:cmd)
      node    = params.dig(:node)
      queue   = params.dig(:queue)
      data    = params.dig(:payload)
      prio    = params.dig(:prio)  || 65536
      ttr     = params.dig(:ttr)   || 10
      delay   = params.dig(:delay) || 2

      job = {
          cmd:  command, # require
          node: node, # require
          timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S' ), # optional
          from: 'grafana', # optional
          payload: data # require
      }.to_json

      result = @mq_Producer.addJob( queue, job, prio, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end

  end

end
