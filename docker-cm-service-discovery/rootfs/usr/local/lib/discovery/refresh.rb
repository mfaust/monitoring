
module ServiceDiscovery

  module Refresh


    def refresh_host_data

      logger.debug( "refresh_host_data" )

      status  = 200
      message = 'initialize message'

      monitoredServer = @database.nodes( status: [ Storage::MySQL::ONLINE ] )

#       logger.debug( monitoredServer )

      if( monitoredServer.nil? || monitoredServer.is_a?( FalseClass ) || monitoredServer.count == 0 )

        logger.info( 'no online server found' )

        return
      end

      monitoredServer.each do |h|

        # get a DNS record
        #
        ip, short, fqdn = self.ns_lookup( h )

        # if the destination host available (simple check with ping)
        #
        unless( Utils::Network.isRunning?( fqdn ) )

          # delete dns entry
          # result  = @database.removeDNS( ip: ip, short: short, fqdn: fqdn )

          # 503 Service Unavailable
          return { status: 503,  message: sprintf( 'Host %s are unavailable', fqdn ) }
        end

        # check discovered datas from the past
        #
        discovery_data    = @database.discoveryData( ip: ip, short: short, fqdn: fqdn )

#         logger.debug( discovery_data )

        current_services = discovery_data.keys.sort

        logger.info( format( 'current %d services: %s', current_services.count, current_services.to_s ) )

#         logger.debug( "#{discovery_data.keys}" )

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

        discovered_services = Hash.new


        # TODO
        # check if @discoveryHost and @discoveryPort setStatus
        # then use the new
        # otherwise use the old code
        start = Time.now

        if( @discovery_host.nil? )

          open = false

          # check open ports and ask for application behind open ports
          #
          ports.each do |p|

            open = Utils::Network.portOpen?( fqdn, p )

            logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

            if( open == true )

              names = self.discover_application({fqdn: fqdn, port: p} )

              logger.debug( "discovered services: #{names}" )

              unless( names.nil? )

                names.each do |name|
                  discovered_services.merge!({name => {'port' => p } } )
                end
              end
            end
          end

        else
          # our new port discover service
          #
          open_ports = []

          pd = PortDiscovery::Client.new( host: @discovery_host, port: @discovery_port )

          if( pd.isAvailable?() )

            open_ports = pd.post( host: fqdn, ports: ports )

            open_ports.each do |p|

              names = self.discover_application( fqdn: fqdn, port: p )

              logger.debug("discovered services: #{names}")

              unless( names.nil? )

                names.each do |name|
                  discovered_services.merge!( { name => {'port' => p} })
                end
              end
            end
          end
        end

        finish = Time.now
        logger.info( sprintf( 'runtime for application discovery: %s seconds', (finish - start).round(2) ) )

        # ---------------------------------------------------------------------------------------------------

        # TODO
        # merge discovered services with additional services
        #
        if( services.is_a?( Array ) && services.count >= 1 )

          services.each do |s|

            service_data = @service_config.dig('services', s )

            unless( service_data.nil? )
              discovered_services[s] ||= service_data.filter('port' )
            end
          end

          found_services = discovered_services.keys

          logger.info( format( '%d usable services: %s', found_services.count, found_services.to_s ) )
        end

        # merge discovered services with cm-services.yaml
        #
        discovered_services = self.create_host_config( ip: ip, short: short, fqdn: fqdn, data: discovered_services )

        found_services = discovered_services.keys.sort

        logger.info( format( 'actual found %d services: %s', found_services.count, found_services.to_s ) )

        if( current_services.count > found_services.count )
          logger.info( 'new service!' )
        elsif( current_services.count < found_services.count )
          logger.info( 'less services (can be ignored)' )
        else
          logger.info( 'equal services' )
        end

      end




    end


  end
end
