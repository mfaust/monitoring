
require_relative '../../utils/network'

class CMGrafana

  module CoreMedia

    module Tools

      def ns_lookup(name, expire = 120 )

        # DNS
        #
        hostname = sprintf( 'dns-%s', name )

        dns      = @cache.get( hostname )

        if( dns.nil? )

          logger.debug( 'create cached DNS data' )
          # create DNS Information
          dns      = Utils::Network.resolv( name )

          ip    = dns.dig(:ip)
          short = dns.dig(:short)
          fqdn  = dns.dig(:long)

          if( ip != nil && short != nil && fqdn != nil )

            @cache.set(hostname , expires_in: expire ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }
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


      # cae-live-1 -> cae-live
      def remove_postfix( service )

        if( service =~ /\d/ )
          last = service.split( '-' ).last
          service  = service.chomp( "-#{last}" )
        end

        service
      end


      def normalize_service( service )

        # normalize service names for grafana
        service = case service
          when 'content-management-server'
            'CMS'
          when 'master-live-server'
            'MLS'
          when 'replication-live-server'
            'RLS'
          when 'workflow-server'
            'WFS'
          when /^cae-live/
            'CAE_LIVE'
          when /^cae-preview/
            'CAE_PREV'
          when 'solr-master'
            'SOLR_MASTER'
      #    when 'solr-slave'
      #      'SOLR_SLAVE'
          when 'content-feeder'
            'FEEDER_CONTENT'
          when 'caefeeder-live'
            'FEEDER_LIVE'
          when 'caefeeder-preview'
            'FEEDER_PREV'
          else
            service
        end

        service.tr('-', '_').upcase

      end


    end

  end

end

