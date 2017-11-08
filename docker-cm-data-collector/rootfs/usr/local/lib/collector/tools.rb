
module DataCollector

  module Tools

    def ns_lookup( name, expire = 45 )

      logger.debug( "ns_lookup( #{name}, #{expire} )" )

      # DNS
      #
      hostname = format( 'dns-%s', name )

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( hostname )

      if( dns.nil? )

        logger.debug( 'no cached DNS data' )

        dns = @database.dnsData( short: name, fqdn: name )

        unless( dns.nil? )

          logger.debug( 'use database entries' )

          ip    = dns.dig('ip')
          short = dns.dig('name')
          fqdn  = dns.dig('fqdn')

          @cache.set( hostname , expires_in: expire ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }

          return ip, short, fqdn
        end

        logger.debug( format( 'resolve dns name %s', name ) )

        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @cache.set( hostname , expires_in: expire ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }
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

      return ip, short, fqdn

    end

  end

end

