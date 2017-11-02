#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.6.0
# -----------------------------------------------------------------------------

require 'json'
require 'yaml'
require 'fileutils'
require 'mini_cache'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'jolokia'
require_relative 'port_discovery'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'discovery/tools'
require_relative 'discovery/queue'
require_relative 'discovery/discovery'

# -------------------------------------------------------------------------------------------------------------------

module ServiceDiscovery

  class Client

    include Logging

    include ServiceDiscovery::Tools
    include ServiceDiscovery::Queue
    include ServiceDiscovery::Discovery

    def initialize( settings = {} )

      ports = [
        80,       # http
        443,      # https
        3306,     # mysql
        5432,     # postgres
        6379,     # redis
        8081,     # Apache mod_status
        9100,     # node_exporter (standard port)
        19100,    # node_exporter (CoreMedia internal)
        28017,    # mongodb
        38099,
        40099,
        40199,
        40299,
        40399,
        40499,
        40599,
        40699,
        40799,
        40899,
        40999,
        41099,
        41199,
        41299,
        41399,
        42099,
        42199,
        42299,
        42399,
        42499,
        42599,
        42699,
        42799,
        42899,
        42999,
        43099,
        44099,
        45099,
        46099,
        47099,
        48099,
        49099,
        55555     # resourced (https://github.com/resourced/resourced)
      ]

      jolokia_host         = settings.dig(:jolokia, :host)           || 'localhost'
      jolokia_port         = settings.dig(:jolokia, :port)           ||  8080
      jolokia_path         = settings.dig(:jolokia, :path)           || '/jolokia'
      jolokia_auth_user    = settings.dig(:jolokia, :auth, :user)
      jolokia_auth_pass    = settings.dig(:jolokia, :auth, :pass)

      @discovery_host      = settings.dig(:discovery, :host)
      @discovery_port      = settings.dig(:discovery, :port)        || 8088
      @discovery_path      = settings.dig(:discovery, :path)        # default: /scan

      mq_host              = settings.dig(:mq, :host)                || 'localhost'
      mq_port              = settings.dig(:mq, :port)                || 11300
      @mq_queue            = settings.dig(:mq, :queue)               || 'mq-discover'

      redis_host           = settings.dig(:redis, :host)
      redis_port           = settings.dig(:redis, :port)             || 6379

      mysql_host           = settings.dig(:mysql, :host)
      mysql_schema         = settings.dig(:mysql, :schema)
      mysql_user           = settings.dig(:mysql, :user)
      mysql_password       = settings.dig(:mysql, :password)

      @service_config      = settings.dig(:configFiles, :service)

      mq_settings      = { beanstalkHost: mq_host, beanstalkPort: mq_port, beanstalkQueue: @mq_queue }
      jolokia_settings = { host: jolokia_host, port: jolokia_port, path: jolokia_path, auth: {user: jolokia_auth_user, pass: jolokia_auth_pass} }
      mysql_settings   = { mysql: { host: mysql_host, user: mysql_user, password: mysql_password, schema: mysql_schema } }

      @scan_ports         = ports

      version             = '1.10.2'
      date                = '2017-10-29'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Service Discovery' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokia_host}:#{jolokia_port}" )
      logger.info( "    - mysql        : #{mysql_host}@#{mysql_schema}" )
      logger.info( "    - message queue: #{mq_host}:#{mq_port}/#{@mq_queue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache       = MiniCache::Store.new
      @jobs        = JobQueue::Job.new
      @jolokia     = Jolokia::Client.new( jolokia_settings )
      @mq_consumer = MessageQueue::Consumer.new(mq_settings )
      @mq_producer = MessageQueue::Producer.new(mq_settings )

      @database   = Storage::MySQL.new(mysql_settings )

      self.read_configurations
    end

    # read Service Configuration
    #
    def read_configurations

      if( @service_config.nil? )
        puts 'missing service config file'
        logger.error( 'missing service config file' )

        raise( 'missing service config file' )
      end

      begin

        if( File.exist?(@service_config ) )
          @service_config      = YAML.load_file(@service_config )
        else
          logger.error( sprintf('Config File %s not found!', @service_config ) )

          raise( sprintf('Config File %s not found!', @service_config ) )
        end

      rescue Exception

        logger.error( 'wrong result (no yaml)')
        logger.error( "#{$!}" )

        raise( 'no valid yaml File' )
      end

    end


    # merge hashes of configured (cm-service.yaml) and discovered data (discovery.json)
    #
    def create_host_config( data )

      return nil unless( data.is_a?(Hash) )

      ip    = data.dig(:ip)
      short = data.dig(:short)
      fqdn  = data.dig(:fqdn)
      data  = data.dig(:data)

      return nil if( data.nil? )

      data.each do |d,v|

        # merge data between discovered Services and our base configuration,
        # the dicovered ports are IMPORTANT
        #
        service_data = @service_config.dig('services', d )

        if (service_data.nil?)
          logger.warn(sprintf('missing entry \'%s\' in cm-service.yaml for merge with discovery data', d))
          logger.warn(sprintf('  remove \'%s\' from data', d))

          data.reject! {|x| x == d}
        else

          data[d].merge!(service_data) {|key, port| port}

          port = data.dig(d, 'port')
          port_http = data.dig(d, 'port_http')

          # when we provide a vhost.json
          #
          unless (service_data.dig('vhosts').nil?)

            logger.info('try to get vhost data')

            begin
              http_vhosts = ServiceDiscovery::HttpVhosts.new({host: fqdn, port: port})
              http_vhosts_data = http_vhosts.tick

              if (http_vhosts_data.is_a?(String))
                http_vhosts_data = JSON.parse(http_vhosts_data)

                http_vhosts_data = http_vhosts_data.dig('vhosts')

                data[d]['vhosts'] = http_vhosts_data
              end
            rescue => e
              logger.error(format('  can\'t get vhost data, error: %s', e))
            end
          end

          if (port != nil && port_http != nil)
            # ATTENTION
            # the RMI Port ends with 99
            # here we subtract 19 from this to get the HTTP Port
            #
            # thist part is hard-coded and VERY ugly!
            #
            data[d]['port_http'] = (port.to_i - 19)
          end

        end
      end

      logger.debug( data )

      data
    end

    # delete the directory with all files inside
    #
    def delete_host(host )

      logger.info( sprintf( 'delete Host \'%s\'',  host ) )

      # get a DNS record
      #
      ip, short, fqdn = self.ns_lookup(host )

      status  = 400
      message = 'Host not in Monitoring'

      # DELETE ONLY WHEN THES STATUS ARE DELETED!
      #
      params = {ip: ip, short: short, fqdn: fqdn, status: [Storage::MySQL::DELETE]}
      nodes = @database.nodes( params )

      logger.debug( "nodes: #{nodes}" )
      logger.debug( "nodes: #{nodes.class.to_s}" )

      if( nodes.is_a?( Array ) && nodes.count != 0 )

        result  = @database.removeDNS( {ip: ip, short: short, fqdn: fqdn} )

        unless( result.nil? )
          return {
              status: 200,
            message: 'Host successful removed'
          }
        end

      else

        status  = 200
        message = 'no hosts in database found'
      end

      {
          status: status,
        message: message
      }

    end

    # add Host and discovery applications
    #
    def add_host(host, options = {} )

      logger.info( sprintf( 'Adding host \'%s\'', host ) )

      if( @jolokia.available? == false )
        logger.error( 'jolokia service is not available!' )
        { status: 500, message: 'jolokia service is not available!' }
      end

      start = Time.now

      # get a DNS record
      #
      ip, short, fqdn = self.ns_lookup( host )

      # if the destination host available (simple check with ping)
      #
      unless( Utils::Network.isRunning?( fqdn ) )

        # delete dns entry
        result  = @database.removeDNS( ip: ip, short: short, fqdn: fqdn )

        return {
          status: 503, # 503 Service Unavailable
          message: sprintf('Host %s are unavailable', host)
        }
      end

      # check discovered datas from the past
      #
      discovery_data    = @database.discoveryData({ip: ip, short: short, fqdn: fqdn} )

      if( discovery_data != nil )

        logger.warn( 'Host already created' )

        # look for online status ...
        #
        status = @database.status( {ip: ip, short: short, fqdn: fqdn} )

        if( status == nil )

          logger.warn( 'host not found' )
          return {
              status: 404,
            message: 'Host not found'
          }
        end

        status = status.dig(:status)

        if( status != nil || status != Storage::MySQL::OFFLINE )

          logger.debug( 'set host status to ONLINE' )
          status = @database.setStatus( {ip: ip, short: short, fqdn: fqdn, status: Storage::MySQL::ONLINE} )
        end

        return {
            status: 409, # 409 Conflict
            message: 'Host already created'
        }

      end

      # -----------------------------------------------------------------------------------

      # get customized configurations of ports and services
      #
      logger.debug( 'ask for custom configurations' )

      ports    = @database.config( {ip: ip, short: short, fqdn: fqdn, key: 'ports'} )
      services = @database.config( {ip: ip, short: short, fqdn: fqdn, key: 'services'} )

      ports    = (ports != nil)    ? ports.dig( 'ports' )       : ports
      services = (services != nil) ? services.dig( 'services' ) : services

      if( ports == nil )
        # our default known ports
        ports = @scan_ports
      end

      if( services == nil )
        # our default known ports
        services = []
      end

      logger.debug( "use ports          : #{ports}" )
      logger.debug( "additional services: #{services}" )

      discovered_services = Hash.new


      # TODO
      # check if @discoveryHost and @discoveryPort setStatus
      # then use the new
      # otherwise use the old code

      use_old_discovery = false

      if (@discovery_host.nil?)
        use_old_discovery = true
      else

        # use new port discover service
        #
        start = Time.now
        open_ports = []

        pd = PortDiscovery::Client.new(host: @discovery_host, port: @discovery_port)

        if (pd.isAvailable?())

          open_ports = pd.post(host: fqdn, ports: ports)

          open_ports.each do |p|

            names = self.discover_application({fqdn: fqdn, port: p})

            logger.debug("discovered services: #{names}")

            unless (names.nil?)

              names.each do |name|
                discovered_services.merge!({name => {'port' => p}})
              end
            end
          end
        else

          use_old_discovery = true
        end

        finish = Time.now
        logger.info(sprintf('runtime for application discovery: %s seconds', (finish - start).round(2)))
        #
        # ---------------------------------------------------------------------------------------------------
      end

      if(use_old_discovery)

        open = false
        start = Time.now

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

        finish = Time.now
        logger.info( sprintf( 'runtime for application discovery: %s seconds', (finish - start).round(2) ) )
      end

      found_services = discovered_services.keys

      logger.info( format( 'found %d services: %s', found_services.count, found_services.to_s ) )

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
      discovered_services = self.create_host_config({ip: ip, short: short, fqdn: fqdn, data: discovered_services} )

      result    = @database.createDiscovery( {ip: ip, short: short, fqdn: fqdn, data: discovered_services} )

      logger.debug( 'set host status to ONLINE' )
      result    = @database.setStatus( {ip: ip, short: short, fqdn: fqdn, status: Storage::MySQL::ONLINE} )

      finish = Time.now
      logger.info( sprintf( 'overall runtime: %s seconds', (finish - start).round(2) ) )

      status = {
          status: 200,
        message: 'Host successful created',
        services: services
      }

      # inform other services ...
      delay = 10

      logger.info( 'create message for grafana dashborads' )
      send_message({cmd: 'add', node: host, queue: 'mq-grafana', payload: options, prio: 10, ttr: 15, delay: 10 + delay.to_i} )

      logger.info( 'create message for icinga checks and notifications' )
      send_message({cmd: 'add', node: host, queue: 'mq-icinga', payload: options, prio: 10, ttr: 15, delay: 10 + delay.to_i} )


      status
    end


    def refresh_host(host )

      status  = 200
      message = 'initialize message'

      host_info = Utils::Network.resolv(host )
      ip       = host_info.dig(:ip)

      if( ip == nil )

        return {
            status: 400,
          message: 'Host not available'
        }

      end

      # second, if the that we want monitored, available
      #
      if(!Utils::Network.isRunning?(ip))

        status  = 400
        message = 'Host not available'
      end

      {
          status: status,
        message: message
      }

    end


    def list_hosts(host = nil )

      logger.debug( "list_hosts( #{host} )" )

      hosts    = Array.new
      result   = Hash.new
      services = Hash.new

      if( host == nil )

        # all nodes, no filter
        #
        # TODO
        # what is with offline or other hosts?
        @database.nodes

      else

        # get a DNS record
        #
        ip, short, fqdn = self.ns_lookup(host )

        discovery_data   = @database.discoveryData({ip: ip, short: short, fqdn: fqdn} )

        if( discovery_data == nil )

          return {
              status: 204,
            message: 'no node data found'
          }

        end

        discovery_data.each do |s|

          data = s.last

          if( data != nil )
            data.reject! { |k| k == 'application' }
            data.reject! { |k| k == 'template' }
          end

          services[s.first.to_sym] ||= {}
          services[s.first.to_sym] = data

        end

        status = nil

        # get node data from redis cache
        #
        (1..15).each {|y|

          result = @database.status({:ip => ip, :short => short, :fqdn => fqdn})

          if (result != nil)
            status = result
            break
          else
            logger.debug(sprintf('Waiting for data ... %d', y))
            sleep(4)
          end
        }

        # parse the creation date
        #
        created        = status.dig( :created )

        if( created.nil? )
          created      = 'unknown'
        else
          created      = Time.parse( created ).strftime( '%Y-%m-%d %H:%M:%S' )
        end

        if( ! status.ia_a?( String ) )

          # parse the online state
          #
          online         = status.dig( :status )

          # and transform the state to human readable
          #
          case online
          when Storage::MySQL::OFFLINE
            status = 'offline'
          when Storage::MySQL::ONLINE
            status = 'online'
          when Storage::MySQL::DELETE
            status = 'delete'
          when Storage::MySQL::PREPARE
            status = 'prepare'
          else
            status = 'unknown'
          end

        end

        {
            status: 200,
          mode: status,
          services: services,
          created: created
        }
      end

    end


  end

end
