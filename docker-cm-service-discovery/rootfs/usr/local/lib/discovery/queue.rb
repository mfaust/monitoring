
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

      if( payload.is_a?( String ) == true && payload.to_s != '' )
        payload  = JSON.parse( payload )
      end

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

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return result

      # remove Node
      #
      elsif( command == 'remove' )

        # check first for existing node!
        #
        result = @database.nodes( { :short => node } )

        logger.debug( "database: '#{result}' | node: '#{node}'" )
        logger.debug( @database.nodes() )

        if( result != nil && result.to_s != node.to_s )

          logger.info( 'node not in monitoring. skipping delete' )

          @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

          return {
            :status  => 200,
            :message => sprintf( 'node not in monitoring. skipping delete ...' )
          }

        end

        begin

          # remove node also from data-collector!
          #
          self.sendMessage( { :cmd => command, :node => node, :queue => 'mq-collector', :payload => { :host => node, :pre => 'prepare' }, :ttr => 1, :delay => 0 } )

          result = self.deleteHost( node )

        rescue => e

          logger.error( e )

        end

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

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
        logger.debug( @redis.nodes() )

        if( result.to_s != node.to_s )

          logger.info( 'node not in monitoring. skipping info' )

          @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

          return {
            :status  => 200,
            :message => sprintf( 'node not in monitoring. skipping info ...' )
          }

        end

#         self.sendMessage( { :cmd => 'info', :queue => 'mq-discover-info', :payload => {}, :ttr => 1, :delay => 0 } )
#
#         return {
#           :status  => 200
#         }

        result = self.listHosts( node )

        status  = result.dig(:status)
        message = result.dig(:message)

        r = {
          :status  => status,
          :message => message
        }

        logger.debug( r )

        self.sendMessage( { :cmd => 'info', :node => node, :queue => 'mq-discover-info', :payload => result, :ttr => 1, :delay => 0 } )

        @jobs.del( { :command => command, :ip => ip, :short => short, :fqdn => fqdn } )

        return {
          :status  => 200,
          :message => 'information succesful send'
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
#
#       if( result.is_a?( String ) )
#         result = JSON.parse( result )
#       end
#
#       result[:request]    = data
#      logger.debug( result )

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
        from: 'discovery',  # optional
        payload: data       # require
      }.to_json

      result = @mqProducer.addJob( queue, job, prio, ttr, delay )

      logger.debug( job )
      logger.debug( result )

    end

  end

end

