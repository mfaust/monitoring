
require_relative '../cache'

class CMIcinga2 < Icinga2::Client

  module Tools

    def nsLookup( name, expire = 120 )

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

          @cache.set( hostname , expiresIn: expire ) { Cache::Data.new( { ip: ip, short: short, long: fqdn } ) }
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

      team_config        = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'team' )
      environment_config = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'environment' )
      aws_config         = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'aws' )
      vhost_http_config  = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'vhost_http' )
      vhost_https_config = @database.config( ip: ip, short: host, fqdn: fqdn, key: 'vhost_https' )

      full_config = @database.config( ip: ip, short: host, fqdn: fqdn )

      logger.debug( "team_config       : #{team_config}" )
      logger.debug( "environment_config: #{environment_config}" )
      logger.debug( "aws_config        : #{aws_config}" )
      logger.debug( "vhost_http_config : #{vhost_http_config}" )
      logger.debug( "vhost_https_config: #{vhost_https_config}" )
      logger.debug( "full_config       : #{full_config}" )

      # in first, we need the discovered services ...
      #
      for y in 1..15

        result = @database.discoveryData( ip: ip, short: host, fqdn: fqdn )

        if( result.is_a?( Hash ) && result.count != 0 )
          services = result
          break
        else
          logger.debug( format( 'waiting for data for node %s ... %d', fqdn, y ) )
          sleep( 5 )
        end
      end

      payload = {}

      unless( services.nil?  )

        services.each do |s|
#          if( s.last.nil? )
            next if( s.last.nil? )
#          end

#          unless( s.last.nil? )
            s.last.reject! { |k| k == 'template' }
            s.last.reject! { |k| k == 'application' }
            s.last.reject! { |k| k == 'description' }
#          end
        end

        if( services.include?('http-proxy') )
          vhosts = services.dig('http-proxy','vhosts')

          if( vhosts.is_a?(Hash) )
            payload['http_vhosts'] = vhosts
          end

          payload['http'] = true
          services.reject! { |k| k == 'http-proxy' }
        end

        if( services.include?('https-proxy') )
          vhosts = services.dig('https-proxy','vhosts')

          if( vhosts.is_a?(Hash) )
            payload['https_vhosts'] = vhosts
          end

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

      if( team_config )
        payload['team'] = parsed_response( team_config )
      end

      if( environment_config )
        payload['environment'] = parsed_response( environment_config )
      end

      # rename all keys
      # replace '-' with '_'
      #
      payload.inject({ }) { |x, (k,v)| x[k.gsub('-', '_')] = v; x }
    end


    def parsed_response( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      logger.error(e)
      return r # do smth
    end

  end

end
