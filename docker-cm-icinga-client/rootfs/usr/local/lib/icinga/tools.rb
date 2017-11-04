
require 'mini_cache'

class CMIcinga2 < Icinga2::Client

  module Tools

    def ns_lookup(name, expire = 120 )

      # DNS
      #
      hostname = format( 'dns-%s', name )

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( hostname )

      if( dns.nil? )
        logger.debug( 'create cached DNS data' )
        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @cache.set(hostname , expires_in: expire ) { MiniCache::Data.new({ ip: ip, short: short, long: fqdn } ) }
        else
          logger.error( 'no DNS data found!' )
          logger.error( " => #{dns}" )
        end
      else

        logger.debug( 're-use cached DNS data' )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)
      end
      #
      # ------------------------------------------------

      logger.debug( format( ' ip   %s ', ip ) )
      logger.debug( format( ' host %s ', short ) )
      logger.debug( format( ' fqdn %s ', fqdn ) )

      [ip, short, fqdn]
    end


    def node_information(params = {} )

      logger.debug( "node_information( #{params} )" )

      ip      = params.dig(:ip)
      host    = params.dig(:host)
      fqdn    = params.dig(:fqdn)

#       full_config        = @database.config( ip: ip, short: host, fqdn: fqdn )
      team_config        = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'team' )
      environment_config = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'environment' )
      aws_config         = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'aws' )
      vhost_http_config  = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'vhost_http' )
      vhost_https_config = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'vhost_https' )

      logger.debug( "team_config       : #{team_config}" )
      logger.debug( "environment_config: #{environment_config}" )
      logger.debug( "aws_config        : #{aws_config}" )
      logger.debug( "vhost_http_config : #{vhost_http_config}" )
      logger.debug( "vhost_https_config: #{vhost_https_config}" )
      logger.debug('---------------------------------------------------------------------')

      # in first, we need the discovered services ...
      #
      for y in 1..30

        logger.debug( format( 'get data for \'%s\' ...', fqdn ) )

        result = @database.discoveryData( ip: ip, short: host, fqdn: fqdn )

        if( result.is_a?( Hash ) && result.count != 0 )
          services = result
          break
        else
          logger.debug( format( 'waiting for data for \'%s\' ... %d', fqdn, y ) )
          sleep( 5 )
        end
      end

      payload = {}

#       logger.debug( JSON.pretty_generate(services) )

      unless( services.nil?  )

        # check, for RLS and CAE(live|preview)
        unless( services.dig('replication-live-server').nil? )

          replicator_value = content_server( fqdn: fqdn, mbean: 'Replicator', service: 'replication-live-server' )

          unless( replicator_value.nil? )

            master_live_server = replicator_value.dig('MasterLiveServer','host')
            logger.debug( "content server for replication-live-server: #{master_live_server}" )

            services['replication-live-server']['master_live_server'] = master_live_server unless( master_live_server.nil? )
          end
        end

        unless( services.dig('cae-live').nil? )

          cap_connection_value = content_server( fqdn: fqdn, mbean: 'CapConnection', service: 'cae-live' )

          unless( cap_connection_value.nil? )

            content_server = cap_connection_value.dig('ContentServer','host')
            logger.debug( "content server for cae-live: #{content_server}" )

            services['cae-live']['content_server'] = content_server unless( content_server.nil? )
          end
        end

        unless( services.dig('cae-preview').nil? )

          cap_connection_value = content_server( fqdn: fqdn, mbean: 'CapConnection', service: 'cae-preview' )

          unless( cap_connection_value.nil? )

            content_server = cap_connection_value.dig('ContentServer','host')
            logger.debug( "content server for cae-preview: #{content_server}" )

            services['cae-preview']['content_server'] = content_server unless( content_server.nil? )
          end
        end

        services.each do |s|
          next if( s.last.nil? )

          s.last.reject! { |k| k == 'template' }
          s.last.reject! { |k| k == 'application' }
          s.last.reject! { |k| k == 'description' }
        end

        if( services.include?('http-proxy') )
          vhosts = services.dig('http-proxy','vhosts')

          payload['http_vhosts'] = vhosts  if( vhosts.is_a?(Hash) )

          payload['http'] = true
          services.reject! { |k| k == 'http-proxy' }
        end

        if( services.include?('https-proxy') )
          vhosts = services.dig('https-proxy','vhosts')

          payload['https_vhosts'] = vhosts if( vhosts.is_a?(Hash) )
          payload['https'] = true
          services.reject! { |k| k == 'https-proxy' }
        end

        if( services.include?('http-status') )
          payload['http_status'] = true
          services.reject! { |k| k == 'http-status' }
        end

        services.each do |k,v|
          payload[k] = v
        end
      end

      if( aws_config )
#        logger.debug(aws_config.class.to_s)
        aws_config = aws_config.dig('aws')
        aws_config = aws_config.gsub( '=>', ':' )
        aws_config = parsed_response( aws_config )

        aws_config.each do |k,v|
          payload["aws_#{k}"] = v
        end

      end

      payload['team']        = parsed_response( team_config )        if( team_config )
      payload['environment'] = parsed_response( environment_config ) if( environment_config )

      # rename all keys
      # replace '-' with '_'
      #
      payload.inject({ }) { |x, (k,v)| x[k.gsub('-', '_')] = v; x }
    end


    def content_server( params )

      fqdn    = params.dig(:fqdn)
      service = params.dig(:service)
      mbean   = params.dig(:mbean)

      # get data from redis
      cache_key = Storage::RedisClient.cacheKey( host: fqdn, pre: 'result', service: service )

      _redis = @redis.get( cache_key )
      _redis = JSON.parse(_redis) if _redis.is_a?(String)

      _bean  = _redis.select { |k,_v| k.dig( mbean ) }
      _bean  = _bean.first if( _bean.is_a?(Array) )

      content_server = nil
      content_server = _bean.dig(mbean,'value') unless( _bean.nil? )
      content_server.values.first unless( _bean.nil? )
    end


    def parsed_response( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      logger.error(e)
      return r # do smth
    end

  end

end

