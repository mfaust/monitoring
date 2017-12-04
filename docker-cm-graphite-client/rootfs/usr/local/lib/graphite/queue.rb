
module Graphite

  module Queue

    # Message-Queue Integration
    #
    #
    #
    def queue

      data = @mq_consumer.get_job_from_tube( @mq_queue )

      if( data.count != 0 )

        stats = @mq_consumer.tube_statistics( @mq_queue )

        logger.debug(
          total: stats.dig(:total),
          ready: stats.dig(:ready),
          delayed: stats.dig(:delayed),
          buried: stats.dig(:buried)
        )

        if( stats.dig(:ready).to_i > 10 )
          logger.warn( 'more then 10 jobs in queue ... just wait' )

          @mq_consumer.clean_queue( @mq_queue )
          return
        end

        job_id  = data.dig(:id )
        result = process_queue( data )
        status = result.dig(:status).to_i

        if( status == 200 || status == 409 || status == 500 || status == 503 )
          @mq_consumer.delete_job( @mq_queue, job_id )
        else
          @mq_consumer.bury_job( @mq_queue, job_id )
        end
      end
    end


    def process_queue( data )

      raise ArgumentError.new(format('wrong type. data must be an Hash, given %s', data.class.to_s ) ) unless( data.is_a?(Hash) )

      logger.info( format( 'process Message ID %d from Queue \'%s\'', data.dig(:id), data.dig(:tube) ) )
      logger.debug( JSON.pretty_generate data )

      command    = data.dig(:body, 'cmd')
      node       = data.dig(:body, 'node')
      payload    = data.dig(:body, 'payload')
      @timestamp = nil

      #
      #
      if( command.nil? || node.nil? || payload.nil? )

        status = 500

        if( command.nil? )
          e = 'missing command'
          logger.error( e )
          logger.error( data )
          return { status: status, message: e }
        end

        if( node.nil? )
          e = 'missing node'
          logger.error( e )
          logger.error( data )
          return { status: status, message: e }
        end

        if( payload.nil? )
          e = 'missing payload'
          logger.error( e )
          logger.error( data )
          return { status: status, message: e }
        end

      end

      payload  = JSON.parse( payload ) if( payload.is_a?( String ) == true && payload.to_s != '' )

      logger.debug( JSON.pretty_generate( payload ) )

      timestamp  = payload.dig('timestamp')
      config     = payload.dig('config')
      dns        = payload.dig('dns')

      if( dns.nil? )
        _ip, _short, fqdn = self.ns_lookup(node )
      else
        fqdn  = dns.dig('fqdn')
      end

      return { status: 500, message: 'missing hostname for annotation' } if( fqdn.nil? )

      @identifier = fqdn

      unless timestamp.nil?

        if (timestamp.is_a?(Time))

          @timestamp = Time.parse(timestamp)

          logger.debug(@timestamp)
        end

        @timestamp = timestamp.to_i
      end

      unless config.nil?

        if (config.is_a?(String) && config.to_s != '')
          config = JSON.parse(config)
        end

        @identifier = config.dig('graphite_identifier')
      end


      logger.info( format( 'add annotation \'%s\' for node \'%s\'', command, fqdn ) )

      case command
      when 'create', 'remove'

        result = self.node_annotation( fqdn, command )

        logger.info( result )

        return { status: 200 }

      when 'loadtest'

        argument = payload.dig( 'argument' )

        if( %w[start stop].include?(argument.downcase) == false )

          logger.error( format( 'wrong argument for LOADTEST \'%s\'', argument ) )

          return { status: 500, message: format( 'wrong argument for LOADTEST \'%s\'', argument ) }
        end

        result = self.loadtest_annotation( fqdn, argument )

        logger.info( result )

        return { status: 200 }

      when 'deployment'

        message = payload.dig( 'message' )
        tags    = payload.dig( 'tags' ) || []

        result = self.deployment_annotation( fqdn, message, tags )

        logger.info( result )

        return { status: 200 }

      when 'general'

        description = payload.dig( 'description' )
        message     = payload.dig( 'message' )
        tags        = payload.dig( 'tags' ) || []

        result = self.general_annotation( fqdn, description, message, tags )

        logger.info( result )

        return { status: 200 }

      else
        logger.error( format( 'wrong command detected: %s', command ) )

        return { status: 500, message: format( 'wrong command detected: %s', command ) }
      end

    end


    def send_message( data )

      raise ArgumentError.new(format('wrong type. data must be an Hash, given %s', data.class.to_s ) ) unless( data.is_a?(Hash) )

      job = {
        cmd:  'information',
        from: 'graphite',
        payload: data
      }.to_json

      logger.debug( JSON.pretty_generate( job ) )

      result = @mq_producer.add_job( queue, job, 1, ttr, delay )

      logger.debug( result )
    end


  end

end
