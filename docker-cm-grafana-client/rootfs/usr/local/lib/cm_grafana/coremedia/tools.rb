
require_relative '../../utils/network'

class CMGrafana

  module Coremedia

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



      # cae-live-1 -> cae-live
      def removePostfix( service )

        if( service =~ /\d/ )
          lastPart = service.split( '-' ).last
          service  = service.chomp( "-#{lastPart}" )
        end

        return service

      end


      def normalizeService( service )

        # normalize service names for grafana
        case service
          when 'content-management-server'
            service = 'CMS'
          when 'master-live-server'
            service = 'MLS'
          when 'replication-live-server'
            service = 'RLS'
          when 'workflow-server'
            service = 'WFS'
          when /^cae-live/
            service = 'CAE_LIVE'
          when /^cae-preview/
            service = 'CAE_PREV'
          when 'solr-master'
            service = 'SOLR_MASTER'
      #    when 'solr-slave'
      #      service = 'SOLR_SLAVE'
          when 'content-feeder'
            service = 'FEEDER_CONTENT'
          when 'caefeeder-live'
            service = 'FEEDER_LIVE'
          when 'caefeeder-preview'
            service = 'FEEDER_PREV'
        end

        return service.tr('-', '_').upcase

      end


    end

  end

end

