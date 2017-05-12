
module ExternalDiscovery

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

#         logger.debug( 'create cached DNS data' )
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

#         logger.debug( 're-use cached DNS data' )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

      end
      #
      # ------------------------------------------------

#       logger.debug( sprintf( ' ip   %s ', ip ) )
#       logger.debug( sprintf( ' host %s ', short ) )
#       logger.debug( sprintf( ' fqdn %s ', fqdn ) )

      return ip, short, fqdn

    end



      def findUid( historic, uid )

        logger.debug( sprintf( 'findUid %s', uid ) )

        if( historic.is_a?(Array) && historic.count() > 0 )

          f = {}

          historic.each do |h|

            f = h.select { |key, value| key.to_s.match(/^id/) }

            if( f[:id].to_s == uid )
              f = h
              break
            else
              f = {}
            end
          end

          return f
        end

      else
        return nil
      end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
