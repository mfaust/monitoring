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

require_relative 'logging'
require_relative 'utils/network'
require_relative 'cache'
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
        9100,     # node_exporter
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

      jolokiaHost         = settings.dig(:jolokia, :host)           || 'localhost'
      jolokiaPort         = settings.dig(:jolokia, :port)           ||  8080
      jolokiaPath         = settings.dig(:jolokia, :path)           || '/jolokia'
      jolokiaAuthUser     = settings.dig(:jolokia, :auth, :user)
      jolokiaAuthPass     = settings.dig(:jolokia, :auth, :pass)

      @discoveryHost       = settings.dig(:discovery, :host)
      @discoveryPort       = settings.dig(:discovery, :port)        || 8088
      @discoveryPath       = settings.dig(:discovery, :path)        # default: /scan

      mqHost              = settings.dig(:mq, :host)                || 'localhost'
      mqPort              = settings.dig(:mq, :port)                || 11300
      @mqQueue            = settings.dig(:mq, :queue)               || 'mq-discover'

      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)             || 6379

      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      @serviceConfig      = settings.dig(:configFiles, :service)

      @MQSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      @scanPorts         = ports

      version             = '1.10.0'
      date                = '2017-10-05'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Service Discovery' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
      logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache      = Cache::Store.new()
      @jobs       = JobQueue::Job.new()
      @jolokia    = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort, :path => jolokiaPath, :auth => { :user => jolokiaAuthUser, :pass => jolokiaAuthPass } } )
      @mqConsumer = MessageQueue::Consumer.new( @MQSettings )
      @mqProducer = MessageQueue::Producer.new( @MQSettings )

      @database   = Storage::MySQL.new({
        :mysql => {
          :host     => mysqlHost,
          :user     => mysqlUser,
          :password => mysqlPassword,
          :schema   => mysqlSchema
        }
      })

      self.readConfigurations()
    end

    # read Service Configuration
    #
    def readConfigurations()

      if( @serviceConfig == nil )
        puts 'missing service config file'
        logger.error( 'missing service config file' )

        raise( 'missing service config file' )
        exit 1
      end

      begin

        if( File.exist?( @serviceConfig ) )
          @serviceConfig      = YAML.load_file( @serviceConfig )
        else
          logger.error( sprintf( 'Config File %s not found!', @serviceConfig ) )

          raise( sprintf( 'Config File %s not found!', @serviceConfig ) )
          exit 1
        end

      rescue Exception

        logger.error( 'wrong result (no yaml)')
        logger.error( "#{$!}" )

        raise( 'no valid yaml File' )
        exit 1
      end

    end


    # merge hashes of configured (cm-service.yaml) and discovered data (discovery.json)
    #
    def createHostConfig( data )

      if( !data.is_a?(Hash) )
        return nil
      end

      ip    = data.dig(:ip)
      short = data.dig(:short)
      fqdn  = data.dig(:fqdn)
      data  = data.dig(:data)

      if( data.nil? )
        return nil
      end

      data.each do |d,v|

        # merge data between discovered Services and our base configuration,
        # the dicovered ports are IMPORTANT
        #
        serviceData = @serviceConfig.dig( 'services', d )

        unless( serviceData.nil? )

          data[d].merge!( serviceData ) { |key, port| port }

          port       = data.dig( d, 'port' )
          port_http  = data.dig( d, 'port_http' )

          # when we provide a vhost.json
          #
          unless( serviceData.dig( 'vhosts' ).nil? )

            logger.info('try to get vhost data')

            begin
              http_vhosts = ServiceDiscovery::HttpVhosts.new( { host: fqdn, port: port } )
              http_vhosts_data = http_vhosts.tick

              if( http_vhosts_data.is_a?(String) )
                http_vhosts_data = JSON.parse( http_vhosts_data )

                http_vhosts_data = http_vhosts_data.dig('vhosts')

                data[d]['vhosts'] = http_vhosts_data
              end
            rescue => e
              logger.error( format( '  can\'t get vhost data, error: %s', e ) )
            end
          end

          if( port != nil && port_http != nil )
            # ATTENTION
            # the RMI Port ends with 99
            # here we subtract 19 from this to get the HTTP Port
            #
            # thist part is hard-coded and VERY ugly!
            #
            data[d]['port_http'] = ( port.to_i - 19 )
          end

        else
          logger.warn( sprintf( 'missing entry \'%s\' in cm-service.yaml for merge with discovery data', d ) )
          logger.warn( sprintf( '  remove \'%s\' from data', d ) )

          data.reject! { |x| x == d }
        end
      end

      logger.debug( data )

      return data
    end

    # delete the directory with all files inside
    #
    def deleteHost( host )

      logger.info( sprintf( 'delete Host \'%s\'',  host ) )

      # get a DNS record
      #
      ip, short, fqdn = self.nsLookup( host )

      status  = 400
      message = 'Host not in Monitoring'

      # DELETE ONLY WHEN THES STATUS ARE DELETED!
      #
      params = { :ip => ip, :short => short, :fqdn => fqdn, :status => [ Storage::MySQL::DELETE ] }
      nodes = @database.nodes( params )

      logger.debug( nodes )

      if( nodes.is_a?( Array ) && nodes.count != 0 )

        result  = @database.removeDNS( { :ip => ip, :short => short, :fqdn => fqdn } )

        if( result != nil )
          status  = 200
          message = 'Host successful removed'
        end

      else

        status  = 200
        message = 'no deleted hosts found'
      end

      return {
        :status  => status,
        :message => message
      }

    end

    # add Host and discovery applications
    #
    def addHost( host, options = {} )

      logger.info( sprintf( 'Adding host \'%s\'', host ) )

      if( @jolokia.jolokiaIsAvailable?() == false )

        return {
          :status  => 500,
          :message => 'jolokia service is not available!'
        }
      end

      start = Time.now

      # get a DNS record
      #
      ip, short, fqdn = self.nsLookup( host )

      # if the destination host available (simple check with ping)
      #
      if( Utils::Network.isRunning?( fqdn ) == false )

        return {
          :status  => 503, # 503 Service Unavailable
          :message => sprintf( 'Host %s are unavailable', host )
        }
      end

      # check discovered datas from the past
      #
      discoveryData    = @database.discoveryData( { :ip => ip, :short => short, :fqdn => fqdn } )

      if( discoveryData != nil )

        logger.warn( 'Host already created' )

        # look for online status ...
        #
        status = @database.status( { :ip => ip, :short => short, :fqdn => fqdn } )

        if( status == nil )

          logger.warn( 'host not found' )
          return {
            :status   => 404,
            :message  => 'Host not found'
          }
        end

        status = status.dig(:status)

        if( status != nil || status != Storage::MySQL::OFFLINE )

          logger.debug( 'set host status to ONLINE' )
          status = @database.setStatus( { :ip => ip, :short => short, :fqdn => fqdn, :status => Storage::MySQL::ONLINE } )
        end

        return {
          :status  => 409, # 409 Conflict
          :message => 'Host already created'
        }

      end

      # -----------------------------------------------------------------------------------

      # get customized configurations of ports and services
      #
      logger.debug( 'ask for custom configurations' )

      ports    = @database.config( { :ip => ip, :short => short, :fqdn => fqdn, :key => 'ports' } )
      services = @database.config( { :ip => ip, :short => short, :fqdn => fqdn, :key => 'services' } )

      ports    = (ports != nil)    ? ports.dig( 'ports' )       : ports
      services = (services != nil) ? services.dig( 'services' ) : services

      if( ports == nil )
        # our default known ports
        ports = @scanPorts
      end

      if( services == nil )
        # our default known ports
        services = []
      end

      logger.debug( "use ports          : #{ports}" )
      logger.debug( "additional services: #{services}" )

      discoveredServices = Hash.new()


      # TODO
      # check if @discoveryHost and @discoveryPort setStatus
      # then use the new
      # otherwise use the old code

      use_old_discovery = false

      unless( @discoveryHost.nil? )

        # use new port discover service
        #
        start = Time.now
        open_ports = []

        pd = PortDiscovery::Client.new( host: @discoveryHost, port: @discoveryPort )

        if( pd.isAvailable?() == true )

          open_ports = pd.post( host: host, ports: ports )

          open_ports.each do |p|

            names = self.discoverApplication( { :fqdn => fqdn, :port => p } )

            logger.debug( "discovered services: #{names}" )

            unless( names.nil? )

              names.each do |name|
                discoveredServices.merge!( { name => { 'port' => p } } )
              end
            end
          end
        else

          use_old_discovery = true
        end

        finish = Time.now
        logger.info( sprintf( 'runtime for application discovery: %s seconds', (finish - start).round(2) ) )
        #
        # ---------------------------------------------------------------------------------------------------
      else
        use_old_discovery = true
      end

      if( use_old_discovery == true )

        open = false
        start = Time.now

        # check open ports and ask for application behind open ports
        #
        ports.each do |p|

          open = Utils::Network.portOpen?( fqdn, p )

          logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

          if( open == true )

            names = self.discoverApplication( { :fqdn => fqdn, :port => p } )

            logger.debug( "discovered services: #{names}" )

            unless( names.nil? )

              names.each do |name|
                discoveredServices.merge!( { name => { 'port' => p } } )
              end
            end
          end
        end

        finish = Time.now
        logger.info( sprintf( 'runtime for application discovery: %s seconds', (finish - start).round(2) ) )
      end

      found_services = discoveredServices.keys

      logger.info( format( 'found %d services: %s', found_services.count, found_services.to_s ) )

      # TODO
      # merge discovered services with additional services
      #
      if( services.is_a?( Array ) && services.count >= 1 )

        services.each do |s|

          serviceData = @serviceConfig.dig( 'services', s )

          unless( serviceData.nil? )
            discoveredServices[s] ||= serviceData.filter( 'port' )
          end
        end

        found_services = discoveredServices.keys

        logger.info( format( '%d usable services: %s', found_services.count, found_services.to_s ) )
      end

      # merge discovered services with cm-services.yaml
      #
      discoveredServices = self.createHostConfig( { :ip => ip, :short => short, :fqdn => fqdn, :data => discoveredServices } )

      result    = @database.createDiscovery( { :ip => ip, :short => short, :fqdn => fqdn, :data => discoveredServices } )

      logger.debug( 'set host status to ONLINE' )
      result    = @database.setStatus( { :ip => ip, :short => short, :fqdn => fqdn, :status => Storage::MySQL::ONLINE } )

      finish = Time.now
      logger.info( sprintf( 'overall runtime: %s seconds', (finish - start).round(2) ) )

      status = {
        :status   => 200,
        :message  => 'Host successful created',
        :services => services
      }

      # inform other services ...
      delay = 10

      logger.info( 'create message for grafana dashborads' )
      sendMessage( { :cmd => 'add', :node => host, :queue => 'mq-grafana', :payload => options, :prio => 10, :ttr => 15, :delay => 10 + delay.to_i } )

      logger.info( 'create message for icinga checks and notifications' )
      sendMessage( { :cmd => 'add', :node => host, :queue => 'mq-icinga', :payload => options, :prio => 10, :ttr => 15, :delay => 10 + delay.to_i } )


      return status
    end


    def refreshHost( host )

      status  = 200
      message = 'initialize message'

      hostInfo = Utils::Network.resolv( host )
      ip       = hostInfo.dig(:ip)

      if( ip == nil )

        return {
          :status  => 400,
          :message => 'Host not available'
        }

      end

      # second, if the that we want monitored, available
      #
      if( Utils::Network.isRunning?( ip ) == false )

        status  = 400
        message = 'Host not available'
      end

      return {
        :status  => status,
        :message => message
      }

    end


    def listHosts( host = nil )

      logger.debug( "listHosts( #{host} )" )

      hosts    = Array.new()
      result   = Hash.new()
      services = Hash.new()

      if( host == nil )

        # all nodes, no filter
        #
        # TODO
        # what is with offline or other hosts?
        nodes = @database.nodes()

        return nodes
      else

        # get a DNS record
        #
        ip, short, fqdn = self.nsLookup( host )

        discoveryData   = @database.discoveryData( { :ip => ip, :short => short, :fqdn => fqdn } )

        if( discoveryData == nil )

          return {
            :status   => 204,
            :message  => 'no node data found'
          }

        end

        discoveryData.each do |s|

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
        for y in 1..15

          result    = @database.status( { :ip => ip, :short => short, :fqdn => fqdn } )

          if( result != nil )
            status = result
            break
          else
            logger.debug( sprintf( 'Waiting for data ... %d', y ) )
            sleep( 4 )
          end
        end

        # parse the creation date
        #
        created        = status.dig( :created )

        if( created == nil )
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
          when Storage::RedisClient::OFFLINE
            status = 'offline'
          when Storage::RedisClient::ONLINE
            status = 'online'
          when Storage::RedisClient::DELETE
            status = 'delete'
          when Storage::RedisClient::PREPARE
            status = 'prepare'
          else
            status = 'unknown'
          end

        end

        result = {
          :status   => 200,
          :mode     => status,
          :services => services,
          :created  => created
        }

        return result

      end

    end


  end

end
