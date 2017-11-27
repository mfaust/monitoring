module Monitoring

  module Host

    # -- HOST -----------------------------------------------------------------------------
    #
  #      example:
  #      {
  #        "force": true,
  #        "discovery": false,
  #        "icinga": false,
  #        "grafana": false,
  #        "tags": [
  #          "development",
  #          "git-0000000"
  #        ],
  #        "annotation": true,
  #        "overview": true,
  #        "config": {
  #          "ports": [50199],
  #          "display_name": "foo.bar.com",
  #          "services": [
  #            "cae-live-1": {},
  #            "content-managment-server": { "port": 41000 }
  #          ]
  #        }
  #      }

    def addHost( host, payload )

  #     logger.debug( sprintf( 'addHost( \'%s\', \'%s\' )', host, payload ) )

      status    = 500
      message   = 'initialize error'

      result    = Hash.new()
      hash      = Hash.new()

      if( host.to_s == '' )

        return JSON.pretty_generate( {
          :status  => 400,
          :message => 'no hostname given'
        } )

      end

      # --------------------------------------------------------------------

      logger.info( sprintf( 'add node \'%s\' to monitoring', host ) )

      alreadyInMonitoring = self.nodeExists?( host )

  #     logger.debug( alreadyInMonitoring ? 'true' : 'false' )

      hostData = self.checkAvailablility?( host )

      return JSON.pretty_generate( status: 400, message: 'Host are not available (DNS Problem)' ) if( hostData == false )

      logger.debug( JSON.pretty_generate( hostData ) )

      ip              = hostData.dig(:ip)
      short           = hostData.dig(:short)
      fqdn            = hostData.dig(:fqdn)

      force           = false
      enableDiscovery = true # @enabledDiscovery
      enabledGrafana  = true # @enabledGrafana
      enabledIcinga   = true # @enabledIcinga
      annotation      = true
      grafanaOverview = true
      services        = []
      tags            = []
      config          = {}

      result[host.to_s] ||= {}

      if( payload.to_s != '' )

        hash = JSON.parse(payload)

        result[host.to_s]['request'] = hash

        force           = hash.keys.include?('force')        ? hash['force']        : false
  #       enableDiscovery = hash.keys.include?('discovery')    ? hash['discovery']    : @enabledDiscovery
  #       enabledGrafana  = hash.keys.include?('grafana')      ? hash['grafana']      : @enabledGrafana
  #       enabledIcinga   = hash.keys.include?('icinga')       ? hash['icinga']       : @enabledIcinga
        annotation      = hash.keys.include?('annotation')   ? hash['annotation']   : true
        grafanaOverview = hash.keys.include?('overview')     ? hash['overview']     : true
        services        = hash.keys.include?('services')     ? hash['services']     : []
        tags            = hash.keys.include?('tags')         ? hash['tags']         : []
        config          = hash.keys.include?('config')       ? hash['config']       : {}
      end

      # logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'overview   : %s', grafanaOverview  ? 'true' : 'false' ) )
      # logger.debug( sprintf( 'services   : %s', services ) )
      # logger.debug( sprintf( 'tags       : %s', tags ) )
      # logger.debug( sprintf( 'config     : %s', config ) )


      if( force == false && alreadyInMonitoring == true )
        logger.warn( "node '#{host}' is already in monitoring" )
        return JSON.pretty_generate( status: 200, message: "node '#{host}' is already in monitoring" )
      end

      # insert the DNS data into the payload
      #
      if( payload.is_a?(String) && payload.size != 0 )
        payload = JSON.parse(payload)
        payload['dns'] = hostData
      end

      payload = { 'dns' => hostData } if( payload.is_a?(String) && payload.size == 0 )
      payload['timestamp'] = Time.now.to_i

      payload = JSON.generate(payload)

      delay = 0

      if( force == true )

        delay = 45

        logger.info( 'force mode ...' )

        logger.info( 'create message for remove node from discovery service' )
        self.messageQueue( cmd: 'remove', node: host, queue: 'mq-discover', payload: payload, prio: 1, ttr: 1, delay: 0 )

        logger.info( 'create message for remove grafana dashboards' )
        self.messageQueue( cmd: 'remove', node: host, queue: 'mq-grafana', payload: payload, prio: 1, ttr: 1, delay: 0 )

        logger.info( 'create message for remove icinga checks and notifications' )
        self.messageQueue( cmd: 'remove', node: host, queue: 'mq-icinga', payload: payload, prio: 1, ttr: 1, delay: 0 )

        sleep(3)

        logger.debug( 'set node status to OFFLINE' )
        status = @database.set_status( ip: ip, short: short, fqdn: fqdn, status: Storage::MySQL::OFFLINE )
        logger.debug(status)

        logger.debug( 'remove configuration' )
        status  = @database.remove_config( ip: ip, short: short, fqdn: fqdn )
        logger.debug(status)

        logger.debug( 'remove dns' )
        status  = @database.remove_dns( ip: ip, short: short, fqdn: fqdn )
        logger.debug(status)

        logger.info( 'done' )

        sleep(4)
      end

      logger.debug(format('add %d seconds delay',delay))

      # create a valid DNS entry
      #
      status = @database.create_dns( ip: ip, short: short, fqdn: fqdn )

      # now, we can write an own configiguration per node when we add them, hurray
      #
      if( config.is_a?( Hash ) )
        logger.debug( "write configuration: #{config}" )
        status = @database.create_config( ip: ip, short: short, fqdn: fqdn, data: config )
      end

      logger.info( 'add node to discovery service' )
      self.messageQueue( cmd: 'add', node: host, queue: 'mq-discover', payload: payload, prio: 1, delay: 2 + delay.to_i )

#       logger.info( 'annotation for create' )
#       annotation(
#         host: host,
#         dns: { ip: ip, short: host, fqdn: fqdn },
#         payload: { command: 'create', argument: 'node', config: config }
#       )

      return JSON.pretty_generate( status: 200, message: 'the message queue is informed ...' )
    end

    #  - http://localhost/api/v2/host
    #  - http://localhost/api/v2/host?short
    #  - http://localhost/api/v2/host/blueprint-box
    #
    def listHost( host = nil, payload = nil )

      data = self.nodeInformations()

      request = payload.dig('rack.request.query_hash')
      short   = request.keys.include?('short')

      logger.debug( data )
      result  = Hash.new()

      return JSON.pretty_generate( status: 204, message: 'no hosts in monitoring found') if( data == nil || data.count == 0 )

      if( host.to_s != '' )

        h = data.dig( host.to_s )

        if ( h != nil )

          if( short == true )
            result[:host] = host
          else
            result[host.to_s] ||= {}
            result[host.to_s] = h
          end
          status = 200
        else
          status = 204
        end

      else
        if( data != nil )
          if( short == true )
            result[:hosts] = data.keys
          else
            result = data
          end
          status = 200
        end
      end

      result[:status] = status

      return JSON.pretty_generate( result )
    end


  #     example:
  #     {
  #       "force": true,
  #       "icinga": false,
  #       "grafana": false,
  #       "annotation": true
  #     }
    def removeHost( host, payload )

      status    = 500
      message   = 'initialize error'

      if( host.to_s == '' )

        return JSON.pretty_generate( {
          :status  => 400,
          :message => 'no hostname given'
        } )

      end

      # --------------------------------------------------------------------

      logger.info( sprintf( 'remove node \'%s\' from monitoring', host ) )

      alreadyInMonitoring = self.nodeExists?( host )
      hostData            = self.checkAvailablility?( host )

      if( hostData == false )
        logger.warn( "DNS PROBLEMS" )

        return JSON.pretty_generate( {
          'status'  => 404,
          'message' => "we have problems with our dns to resolve '#{host}' :("
        })
      end

      result    = Hash.new()
      hash      = Hash.new()

      enableDiscovery = true # @enabledDiscovery
      enabledGrafana  = true # @enabledGrafana
      enabledIcinga   = true # @enabledIcinga
      annotation      = true

      result[host.to_s] ||= {}

      if( payload != '' )

        hash = JSON.parse( payload )

        result[host.to_s]['request'] = hash

        force           = hash.keys.include?('force')      ? hash['force']      : false
        enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
        enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
        annotation      = hash.keys.include?('annotation') ? hash['annotation'] : true
      end

      if( alreadyInMonitoring == false && force == false )
        logger.warn( "node '#{host}' is not in monitoring" )

        return JSON.pretty_generate( {
          'status'  => 200,
          'message' => "node '#{host}' is not in monitoring"
        })
      end

      if( alreadyInMonitoring == false && force == true )
        logger.warn( "node '#{host}' is not in monitoring" )
        logger.warn( "but force delete" )

        annotation = false
      end

      ip    = hostData.dig(:ip)
      short = hostData.dig(:short)
      fqdn  = hostData.dig(:fqdn)

      # read the customized configuration
      #
      config = @database.config( { :ip => ip, :short => host, :fqdn => fqdn } )

  #     logger.debug( 'set node status to DELETE' )
      status = @database.set_status( { :ip => ip, :short => host, :fqdn => fqdn, :status => Storage::MySQL::DELETE } )

      # insert the DNS data into the payload
      #

      payload = Hash.new
      payload = {
        'dns'   => hostData,
        'force' => true,
        'timestamp' => Time.now.to_i
      }

      payload = JSON.generate(payload)

  #    logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
  #    logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
  #    logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
  #    logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
  #    logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )

      logger.info( 'annotation for remove' )
      annotation(
        host: host,
        dns: { ip: ip, short: host, fqdn: fqdn },
        payload: { command: 'remove', argument: 'node', config: config }
      )

  #    self.addAnnotation( host, { 'command' => 'remove', 'argument' => 'node', 'config' => config } )

      logger.info( 'remove icinga checks and notifications' )
      self.messageQueue( cmd: 'remove', node: host, queue: 'mq-icinga', payload: payload, prio: 0 )

      logger.info( 'remove grafana dashboards' )
      self.messageQueue( cmd: 'remove', node: host, queue: 'mq-grafana', payload: payload, prio: 0 )

      logger.info( 'remove node from discovery service' )
      self.messageQueue( cmd: 'remove', node: host, queue: 'mq-discover', payload: payload, prio: 0, delay: 5 )

      @database.remove_dns( { :short => host } )

      result['status']    = 200
      result['message']   = 'the message queue is informed ...'

      return JSON.pretty_generate( result )

    end



  end
end
