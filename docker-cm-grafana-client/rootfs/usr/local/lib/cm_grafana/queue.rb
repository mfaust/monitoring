
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

        result = self.process_queue(data)

        logger.debug(result)

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

      payload  = JSON.parse( payload ) if( payload.is_a?( String ) == true && payload.to_s != '' )

      logger.debug( JSON.pretty_generate payload )

      tags       = payload.dig('tags')
      overview   = payload.dig('overview') || true
      dns        = payload.dig('dns')
      annotation = payload.dig('annotation') || false
      timestamp  = payload.dig('timestamp') || Time.now.to_i
      type       = payload.dig('type')
      argument   = payload.dig('argument')
      message    = payload.dig('message')
      tags       = payload.dig('tags')

      logger.info( format( '%s host \'%s\'', command , node ) )

#       logger.debug( "dns: #{dns} (#{dns.class.to_s})" )

      if( dns.is_a?(Hash) )
        ip = dns.dig('ip')
        short = dns.dig('short')
        fqdn = dns.dig('fqdn')
      end

#       logger.debug( "ip: #{ip} (#{ip.class.to_s})" )
#       logger.debug( "short: #{short} (#{short.class.to_s})" )
#       logger.debug( "fqdn: #{fqdn} (#{fqdn.class.to_s})" )

      ip, short, fqdn = self.ns_lookup(node) if( ip == nil && short == nil && fqdn == nil )

      # no DNS data?
      #
      if( ip == nil && short == nil && fqdn == nil )

        logger.warn( 'we found no dns data!' )

        # ask grafana
        #
        result = self.list_dashboards( host: node )
        logger.debug( result )
        return { status: 500, message: 'no dns data found' }
      end

      job_option = { command: command, ip: ip, short: short, fqdn: fqdn }

      return { status: 409, message: 'we are working on this job' } if( @jobs.jobs( job_option ) == true )

      @jobs.add( job_option )

      @cache.set(format( 'dns-%s', node ) , expires_in: 320 ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }

      identifier  = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'graphite_identifier' )

      if( identifier != nil && identifier.dig( 'graphite_identifier' ) != nil )
        identifier = identifier.dig( 'graphite_identifier' ).to_s
        logger.info( "use custom storage identifier from config: '#{identifier}'" )
      else
        identifier = short
      end

      # use grafana annotations
      #
      #
      if( command == 'annotation' )

#         logger.debug( JSON.pretty_generate payload )

        params = {}

#         logger.debug(payload)

        time     = Time.at( timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )

#         logger.debug( "type: #{type}" )

        unless( %w[loadtest deployment].include?(type) )

          # TODO
          # general and free-text annotation ...
          params = {}
        end

        # loadtest start / stop
        if( type == 'loadtest' )
          params = {
            what: format( 'loadtest %s', argument ),
            when: timestamp,
            tags: [ identifier, 'loadtest', argument ],
            text: sprintf( 'Loadtest for Node <b>%s</b> %sed (%s)', node, argument, time )
          }
        end

        # deployment
        if( type == 'deployment' )

          tag = [ identifier, 'deployment' ]

          if( tags.count != 0 )
            tag << tags
            tag.flatten!
          end

          params = {
            what: format( 'Deployment %s', message ),
            when: timestamp,
            tags: tag,
            text: sprintf( 'Deployment on Node <b>%s</b> started (%s)', node, time )
          }
        end

        logger.debug(params)

        if( params.count.zero? )
          logger.debug( 'nothing to do ...' )
          return { status: 200, message: 'nothing to do ...' }
        end

        begin
          result = create_annotation_graphite( params )
          logger.debug(params)
          logger.debug( result )
        rescue => error
          logger.error( error)
        end

        @jobs.del( job_option )

        return { status: 200, message: result }
      end


      # add Node
      #
      if( command == 'add' )

        # add annotation
        if(annotation==true)

          time     = Time.at( timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )  #unless( timestamp.nil? )

          params = {
            what: 'node created',
            when: timestamp,
            tags: [ identifier, 'created' ],
            text: format( 'Node <b>%s</b> created (%s)', node, time )
          }

          begin
            result = create_annotation_graphite( params )
            logger.debug(params)
            logger.debug( result )
          rescue => error
            logger.error( error)
          end
        end

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

        # add annotation
        if(annotation==true)

          time     = Time.at( timestamp ).strftime( '%Y-%m-%d %H:%M:%S' )  #unless( timestamp.nil? )

          params = {
            what: 'node destroyed',
            when: timestamp,
            tags: [ identifier, 'destroyed' ],
            text: format( 'Node <b>%s</b> destroyed (%s)', node, time )
          }

          begin
            result = create_annotation_graphite( params )
            logger.debug(params)
            logger.debug( result )
          rescue => error
            logger.error( error)
          end
        end


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

      { status: 500, message: format( 'wrong command detected: %s', command ) }
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
