
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

      return ip, short, fqdn

    end


    def nodeTag( host )

#       logger.debug( "nodeTag( #{host} )" )

      key    = sprintf( 'config-%s', host )
      data   = @cache.get( key )

      result = host

      if( data == nil )

        identifier = @redis.config( { :short => host, :key => 'graphite-identifier' } )

        if( identifier != nil )

          identifier = identifier.dig( 'graphite-identifier' )

          if( identifier != nil )
            result     = identifier
          end

          @cache.set( key, expiresIn: 320 ) { Cache::Data.new( result ) }
        end

      else

        result = data
      end

      return result

    end


    def nodeInformation( params = {} )

      logger.debug( "nodeInformation( #{params} )" )

      host             = params.dig(:host) || nil

      # in first, we need the discovered services ...
      logger.debug( sprintf( 'in first, we need information from discovery service for node \'%s\'', host ) )

      for y in 1..30

        result = @redis.discoveryData( { :short => host } )

        if( result.is_a?( Hash ) && result.count != 0 )

          services = result
          break
        else
          logger.debug( sprintf( 'waiting for data for node %s ... %d', host, y ) )
          sleep( 5 )
        end
      end

      logger.debug( "#{services}" )

      if( services != nil )

        services.each do |s|

#           logger.debug( " => service #{s}" )

          if( s.last != nil )
            s.last.reject! { |k| k == 'template' }
            s.last.reject! { |k| k == 'application' }
          end
        end

        payload = { "coremedia": services }
      else

        payload = {}
      end

      logger.debug( JSON.pretty_generate( payload ) )

      return payload

    end


  end

end
