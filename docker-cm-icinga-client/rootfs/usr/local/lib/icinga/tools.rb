
require_relative '../cache'

class CMIcinga2 < Icinga2::Client

  module Tools

    def nsLookup( name, expire = 120 )

      # DNS
      #
      hostname = sprintf( 'dns-%s', name )

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( hostname )

      if( dns == nil )
        logger.debug( 'create cached DNS data' )
        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @cache.set( hostname , expiresIn: expire ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
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

      logger.debug( sprintf( ' ip   %s ', ip ) )
      logger.debug( sprintf( ' host %s ', short ) )
      logger.debug( sprintf( ' fqdn %s ', fqdn ) )

      [ip, short, fqdn]
    end


    def nodeInformation( params = {} )

      logger.debug( "nodeInformation( #{params} )" )

      ip      = params.dig(:ip)
      host    = params.dig(:host)
      fqdn    = params.dig(:fqdn)

      team_config        = @database.config( { :ip => ip, :short => host, :fqdn => fqdn, :key => 'team' } )
      environment_config = @database.config( { :ip => ip, :short => host, :fqdn => fqdn, :key => 'environment' } )
      aws_config         = @database.config( { :ip => ip, :short => host, :fqdn => fqdn, :key => 'aws' } )
      vhost_http_config  = @database.config( { :ip => ip, :short => host, :fqdn => fqdn, :key => 'vhost_http' } )
      vhost_https_config = @database.config( { :ip => ip, :short => host, :fqdn => fqdn, :key => 'vhost_https' } )

      logger.debug( "team_config       : #{team_config}" )
      logger.debug( "environment_config: #{environment_config}" )
      logger.debug( "aws_config        : #{aws_config}" )
      logger.debug( "vhost_http_config : #{vhost_http_config}" )
      logger.debug( "vhost_https_config: #{vhost_https_config}" )

      # in first, we need the discovered services ...
      #
      for y in 1..30

        result = @database.discoveryData( { :ip => ip, :short => host, :fqdn => fqdn } )

        if( result.is_a?( Hash ) && result.count != 0 )
          services = result
          break
        else
          logger.debug( sprintf( 'waiting for data for node %s ... %d', fqdn, y ) )
          sleep( 5 )
        end
      end

      payload = {}

      if( services != nil )

#         logger.debug( JSON.pretty_generate( services ) )

        services.each do |s|
          if( s.last != nil )
            s.last.reject! { |k| k == 'template' }
            s.last.reject! { |k| k == 'application' }
            s.last.reject! { |k| k == 'description' }
          end
        end

#         logger.debug(services)
#         logger.debug(services.class.to_s)
#
#         payload = { 'coremedia': services }

        if( services.include?('http-proxy') )
          vhosts = services.dig('http-proxy','vhosts')

          unless( vhosts.nil? )
            payload['http_vhosts'] = vhosts
          end

          payload['http']        = true
          services.reject! { |k| k == 'http-proxy' }
        end

        if( services.include?('https-proxy') )
          vhosts = services.dig('https-proxy','vhosts')

          unless( vhosts.nil? )
            payload['https_vhosts'] = vhosts
          end

          payload['https']        = true
          services.reject! { |k| k == 'https-proxy' }
        end

        if( services.include?('http-status') )
          payload['http_status']        = true
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

        payload['aws'] = self.parsedResponse( aws_config )
      end

      if( team_config )
        payload['team'] = self.parsedResponse( team_config )
      end

      if( environment_config )
        payload['environment'] = self.parsedResponse( environment_config )
      end


      payload
    end


    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth
    end

  end

end
