module Monitoring

  module Host

    # -- HOST -----------------------------------------------------------------------------
    #
  #      example:
  #      {
  #        "force": true,
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
  #            "cae-live-1",
  #            "content-managment-server"
  #          ],
  #          "group_by": [
  #            "dev",
  #            "management"
  #          ]
  #        }
  #      }

    def add_host( host, payload )

      return JSON.pretty_generate( status: 400, message: 'no hostname given' ) if( host.to_s == '' )

      hash             = {}
      force            = false
      annotation       = true
      grafana_overview = true
      overview_grouped_by = []
      services         = []
      tags             = []
      config           = {}

      result           = {}
      result[host.to_s] ||= {}

      if( payload.to_s != '' )

        hash = JSON.parse(payload)

        result[host.to_s]['request'] = hash

        if( hash.is_a?(Hash) )

          logger.debug(JSON.pretty_generate(hash))

          force               = hash.dig('force')               || false
          annotation          = hash.dig('annotation')          || true
          grafana_overview    = hash.dig('overview')            || true
          services            = hash.dig('services')            || []
          tags                = hash.dig('tags')                || []
          config              = hash.dig('config')              || {}
        end
      end

      sanity_force    = ( !force.nil? && force.is_a?(Boolean) )
      sanity_tags     = ( !tags.nil? && tags.is_a?(Array) )
      sanity_config   = ( !config.nil? && config.is_a?(Hash) )

      # no overview -> no group by
      overview_grouped_by = []  if(grafana_overview == false)

      logger.debug( format( 'force          : %s (%s)', force            ? 'true' : 'false', force.class.to_s))
      logger.debug( format( 'overview       : %s (%s)', grafana_overview ? 'true' : 'false', grafana_overview.class.to_s))
      logger.debug( format( 'annotation     : %s (%s)', annotation       ? 'true' : 'false', annotation.class.to_s))
      logger.debug( format( 'services       : %s (%s)', services , services.class.to_s) )
      logger.debug( format( 'tags           : %s (%s)', tags , tags.class.to_s) )
      logger.debug( format( 'config         : %s (%s)', config , config.class.to_s) )

      logger.debug( format( 'sanity_force   : %s (%s)', sanity_force ? 'true' : 'false', sanity_force.class.to_s))
      logger.debug( format( 'sanity_tags    : %s (%s)', sanity_tags  ? 'true' : 'false', sanity_tags.class.to_s))
      logger.debug( format( 'sanity_config  : %s (%s)', sanity_config   ? 'true' : 'false', sanity_config.class.to_s))

      if( sanity_force == false || sanity_tags == false || sanity_config == false )

        message = []
        message << format('wrong type. \'force\' must be an Boolean, given \'%s\'', force.class.to_s) unless sanity_force
        message << format('wrong type. \'tags\' must be an Array, given \'%s\'', tags.class.to_s) unless sanity_tags
        message << format('wrong type. \'config\' must be an Hash, given \'%s\'', config.class.to_s) unless sanity_config

        return JSON.pretty_generate( status: 400, message: message )
      end

      # --------------------------------------------------------------------

      in_monitoring = host_exists?( host )
      host_data     = host_avail?( host )

      logger.debug( "in_monitoring:  #{in_monitoring}" )
      logger.debug( "host_data    :  #{JSON.pretty_generate( host_data )}" )

      return JSON.pretty_generate( status: 400, message: 'Host are not available (DNS Problem)' ) if( host_data == false )

      ip    = host_data.dig(:ip)
      short = host_data.dig(:short)
      fqdn  = host_data.dig(:fqdn)

      return JSON.pretty_generate( status: 200, message: "Host '#{host}' is already in monitoring" ) if( force == false && in_monitoring == true )

      # --------------------------------------------------------------------

      logger.info( format( 'add host \'%s\' to monitoring', host ) )

      if( payload.is_a?(String) && payload.size == 0 )
        payload = {}
      else
        payload = JSON.parse( payload )
      end

      # payload = payload.deep_symbolize_keys
      payload[:timestamp]  = Time.now.to_i
      payload[:dns]        = host_data
#       payload[:annotation] = annotation

      delay = 0

      if( force == true )

        delay = 45
        payload[:annotation] = false

        logger.info( 'force mode ...' )

        logger.info( 'create message for remove node from discovery service' )
        message_queue( cmd: 'remove', node: host, queue: 'mq-discover', payload: payload, prio: 1, ttr: 1, delay: 0 )

        logger.info( 'create message for remove grafana dashboards' )
        message_queue( cmd: 'remove', node: host, queue: 'mq-grafana', payload: payload, prio: 1, ttr: 1, delay: 0 )

        logger.info( 'create message for remove icinga checks and notifications' )
        message_queue( cmd: 'remove', node: host, queue: 'mq-icinga', payload: payload, prio: 1, ttr: 1, delay: 0 )

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
      end

      logger.debug(format('add %d seconds delay', delay)) if( delay > 0 )

      # create a valid DNS entry
      #
      status = @database.create_dns( ip: ip, short: short, fqdn: fqdn )

# logger.debug( JSON.pretty_generate( payload ) )

      # now, we can write an own configiguration per node when we add them, hurray
      #
      if( config.is_a?( Hash ) )
        logger.debug( "write configuration: #{config}" )
        status = @database.create_config( ip: ip, short: short, fqdn: fqdn, data: config )
      end

      logger.info( 'create message for discovery service' )
      message_queue( cmd: 'add', node: host, queue: 'mq-discover', payload: payload, prio: 1, delay: 2 + delay.to_i )

      logger.info('sucessfull')

      return JSON.pretty_generate( status: 200, message: 'the message queue is informed ...' )
    end

    #  - http://localhost/api/v2/host
    #  - http://localhost/api/v2/host?short
    #  - http://localhost/api/v2/host/blueprint-box
    #
    def list_host( host = nil, payload = nil )

      logger.debug( "list_host( #{host}, #{payload} )" )

      request = payload.dig('rack.request.query_hash')
      short   = request.keys.include?('short')
      data    = host_informations()

      logger.debug( data )
      logger.debug( data.class.to_s )

      result  = {}

      return JSON.pretty_generate( status: 204 ) if( data.nil? || data.count == 0 )

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
  #       "grafana": false,
  #     }
    def delete_host( host, payload )

      return JSON.pretty_generate( status: 400, message: 'no hostname given' ) if( host.to_s == '' )

      # --------------------------------------------------------------------

      logger.info( format( 'remove host \'%s\' from monitoring', host ) )

      in_monitoring = host_exists?( host )
      host_data     = host_avail?( host )

      return JSON.pretty_generate( status: 404, message: format('we have problems with our dns to resolve \'%s\'', host ) ) if( host_data == false )

      result    = Hash.new()
      hash      = Hash.new()

      annotation      = true

      result[host.to_s] ||= {}

      if( payload != '' )

        hash = JSON.parse( payload )

        result[host.to_s]['request'] = hash

        force           = hash.keys.include?('force')      ? hash['force']      : false
        enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
      end

      return JSON.pretty_generate( status: 200, message: format( 'host \'%s\' is not in monitoring', host ) ) if( in_monitoring == false && force == false )

      annotation = false if( in_monitoring == false && force == true )

#       logger.warn( "force delete" )
#       logger.warn( "but node '#{host}' is not in monitoring" )

      ip    = host_data.dig(:ip)
      short = host_data.dig(:short)
      fqdn  = host_data.dig(:fqdn)

      # read the customized configuration
      #
      config = @database.config( ip: ip, short: host, fqdn: fqdn )

      status = @database.set_status( ip: ip, short: host, fqdn: fqdn, status: Storage::MySQL::DELETE )

      # insert the DNS data into the payload
      #
      payload = Hash.new
      payload = {
        dns: host_data,
        force: true,
        timestamp: Time.now.to_i,
        annotation: true
      }
      logger.debug( JSON.pretty_generate( payload ) )
      # payload = JSON.generate(payload)

  #    logger.debug( format( 'force      : %s', force            ? 'true' : 'false' ) )
  #    logger.debug( format( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
  #    logger.debug( format( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
  #    logger.debug( format( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
  #    logger.debug( format( 'annotation : %s', annotation       ? 'true' : 'false' ) )

#       logger.debug( 'annotation for remove' )
#       annotation(
#         host: host,
#         dns: { ip: ip, short: host, fqdn: fqdn },
#         payload: { command: 'remove', argument: 'node', config: config }
#       )

      logger.info( 'create message for remove node from discovery service' )
      message_queue( cmd: 'remove', node: host, queue: 'mq-discover', payload: payload, prio: 1, ttr: 1, delay: 0 )
#      message_queue( cmd: 'remove', node: host, queue: 'mq-discover', payload: payload, prio: 1, delay: 5 )

      logger.info( 'create message for remove icinga checks and notifications' )
      message_queue( cmd: 'remove', node: host, queue: 'mq-icinga', payload: payload, prio: 1, ttr: 1, delay: 0 )

      logger.info( 'create message for remove grafana dashboards' )
      message_queue( cmd: 'remove', node: host, queue: 'mq-grafana', payload: payload, prio: 1, ttr: 1, delay: 0 )

      sleep(3)

      logger.debug( 'set node status to OFFLINE' )
      status = @database.set_status( ip: ip, short: short, fqdn: fqdn, status: Storage::MySQL::OFFLINE )

      logger.debug( 'remove configuration' )
      status  = @database.remove_config( ip: ip, short: short, fqdn: fqdn )
      logger.debug(status)

      logger.debug( 'remove dns' )
      status  = @database.remove_dns( ip: ip, short: short, fqdn: fqdn )

      #@database.remove_dns( short: host )

      logger.info('sucessfull')

      return JSON.pretty_generate( status: 200, message: 'the message queue is informed ...' )
    end

  end
end
