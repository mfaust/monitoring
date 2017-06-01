
require_relative '../cache'

module Icinga2

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

  end

end
