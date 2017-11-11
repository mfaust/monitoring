
module ServiceDiscovery

  module Refresh


    def refresh_host_data

      monitoredServer = @database.nodes( status: [ Storage::MySQL::ONLINE ] )

      return { status: 204,  message: 'no online server found' } if( monitoredServer.nil? || monitoredServer.is_a?( FalseClass ) || monitoredServer.count == 0 )

      monitoredServer.each do |h|

        # get a DNS record
        #
        ip, short, fqdn = self.ns_lookup( h )

        # if the destination host available (simple check with ping)
        #
        # 503 Service Unavailable
        return { status: 503,  message: sprintf( 'Host %s are unavailable', fqdn ) } unless( Utils::Network.isRunning?( fqdn ) )

        known_services_count, known_services_array       = known_services( ip: ip, short: short, fqdn: fqdn ).values
        actually_services_count, actually_services_array, data = actually_services( ip: ip, short: short, fqdn: fqdn ).values

        # TODO
        # compare both arrays
        # identicalEntries      = known_services_array & actually_services_array
        # removedEntries        = actually_services_array - known_services_array
        # newEntries            = known_services_array - identicalEntries
        #
        # known_dataCount       = known_services_array.count
        # actually_dataCount    = actually_services_array.count
        # identicalEntriesCount = identicalEntries.count
        # removedEntriesCount   = removedEntries.count
        # newEntriesCount       = newEntries.count

        # logger.debug( '------------------------------------------------------------' )
        # logger.info( sprintf( 'known entries %d', known_dataCount ) )
        # logger.info( sprintf( 'actually entries %d', actually_dataCount ) )
        # logger.debug( '------------------------------------------------------------' )
        # logger.info( sprintf( 'identical entries %d', identicalEntriesCount ) )
        # #logger.debug(  "  #{identicalEntries}" )
        # logger.info( sprintf( 'new entries %d', newEntriesCount ) )
        # #logger.debug(  "  #{newEntries}" )
        # logger.info( sprintf( 'removed entries %d', removedEntriesCount ) )
        # #logger.debug(  "  #{removedEntries}" )
        # logger.debug( '------------------------------------------------------------' )

        if( known_services_count < actually_services_count )

          logger.info( 'new service detected' )

          # step 1
          # update our database
          result    = @database.createDiscovery( ip: ip, short: short, fqdn: fqdn, data: data )

          options = { dns: { ip: ip, short: short, fqdn: fqdn } }
          host    = fqdn
          delay = 10

          # step 2
          # create a job for update icinga
          logger.info( 'create message for grafana to create or update dashboards' )
          send_message( cmd: 'update', node: host, queue: 'mq-grafana', payload: options, prio: 10, ttr: 15, delay: 10 + delay.to_i )

          # step 3
          # create a job for update grafana
          logger.info( 'create message for icinga to update host and apply checks and notifications' )
          send_message( cmd: 'update', node: host, queue: 'mq-icinga', payload: options, prio: 10, ttr: 15, delay: 10 + delay.to_i )

        elsif( known_services_count > actually_services_count )
          logger.info( 'less services (will be ignored)' )
        else
          logger.info( 'equal services' )
        end

      end
    end

    def known_services( params )

      ip    = params.dig(:ip)
      short = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      # check discovered datas from the past
      #
      discovery_data   = @database.discoveryData( ip: ip, short: short, fqdn: fqdn )
      services = discovery_data.keys.sort

      services_count   = services.count
      logger.info( format( 'i known %d services', services_count ) )
      logger.debug( services.to_s )

      { count: services_count, services: services }
    end


    def actually_services( params )

      ip    = params.dig(:ip)
      short = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      # get customized configurations of ports and services
      #
      logger.debug( 'ask for custom configurations' )

      ports    = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'ports' )
      services = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'services' )

      ports    = (ports != nil)    ? ports.dig( 'ports' )       : ports
      services = (services != nil) ? services.dig( 'services' ) : services

      # our default known ports
      ports = @scan_ports if( ports.nil? )

      # our default known ports
      services = [] if( services.nil? )

      logger.debug( "use ports          : #{ports}" )
      logger.debug( "additional services: #{services}" )

      discovered_services = discover( ip: ip, short: short, fqdn: fqdn, ports: ports )
      discovered_services = merge_services( discovered_services, services )
      discovered_services = create_host_config( ip: ip, short: short, fqdn: fqdn, data: discovered_services )

      services = discovered_services.keys.sort
      services_count = services.count

      logger.info( format( 'currently there are %s services', services_count ) )
      logger.debug( services.to_s )

      { count: services_count, services: services, discovery_data: discovered_services }
    end

  end
end
