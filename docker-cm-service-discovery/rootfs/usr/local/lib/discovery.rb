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
        3306,     # mysql
        5432,     # postrgres
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

      version             = '1.7.0'
      date                = '2017-06-02'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Service Discovery' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
      logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
      if( mysqlHost != nil )
        logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      end
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache      = Cache::Store.new()
      @jobs       = JobQueue::Job.new()
      @redis      = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
      @jolokia    = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort, :path => jolokiaPath, :auth => { :user => jolokiaAuthUser, :pass => jolokiaAuthPass } } )
      @mqConsumer = MessageQueue::Consumer.new( @MQSettings )
      @mqProducer = MessageQueue::Producer.new( @MQSettings )
      @database   = nil

      if( mysqlHost != nil )

        begin

          until( @database != nil )

            logger.debug( 'try to connect our database endpoint' )

            @database   = Storage::MySQL.new( {
              :mysql => {
                :host     => mysqlHost,
                :user     => mysqlUser,
                :password => mysqlPassword,
                :schema   => mysqlSchema
              }
            } )

            sleep(5)
          end
        rescue => e

          logger.error( e )
        end
      end

      self.readConfigurations()
    end

    # read Service Configuration
    #
    def readConfigurations()

  #     logger.info( 'read defines of Services Properties' )

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

  #    logger.debug( "createHostConfig( #{data} )" )

      data.each do |d,v|

        # merge data between discovered Services and our base configuration,
        # the dicovered ports are IMPORTANT
        #
        serviceData = @serviceConfig.dig( 'services', d )

        if( serviceData != nil )

  #         logger.debug( @serviceConfig['services'][d] )

          data[d].merge!( serviceData ) { |key, port| port }

          port       = data.dig( d, 'port' )
          port_http  = data.dig( d, 'port_http' )

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
        end
      end

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

      if( @database != nil )
        result = @database.removeDNS( { :short => short } )

        logger.debug( "database: #{result}" )
      end

      result = @redis.removeDNS( { :short => short } )

      logger.debug( "redis: #{result}" )

      if( result != nil )

        status  = 200
        message = 'Host successful removed'
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

      # add hostname to an blocking cache
      #
      if( @jobs.jobs( { :ip => ip, :short => short, :fqdn => fqdn } ) == true )

        logger.warn( 'we are working on this job' )

        return {
          :status  => 409, # 409 Conflict
          :message => 'we are working on this job'
        }
      end

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
      if( @database != nil )

        discoveryData    = @database.discoveryData( { :short => short } )
        logger.debug( "database: #{discoveryData}" )

        if( discoveryData != nil )

          logger.debug( JSON.pretty_generate( discoveryData ) )
          logger.error( 'Host already created' )

          # look for online status ...
          #
          status = @database.status( { :short => host } )

          if( status == nil )

            logger.warn( 'host not found' )
            return {
              :status   => 404,
              :message  => 'Host not found'
            }
          end

          logger.debug( status )
          logger.debug( status.class.to_s )

          status = status.dig(:status)

          if( status != nil || status != Storage::MySQL::OFFLINE )

            logger.debug( 'set host status to ONLINE' )
            status = @database.setStatus( { :short => host, :status => Storage::MySQL::ONLINE } )
          end

#           return {
#             :status  => 409, # 409 Conflict
#             :message => 'Host already created'
#           }

        end

      end


      discoveryData = @redis.discoveryData( { :short => host } )

      if( discoveryData != nil )

        logger.debug( JSON.pretty_generate( discoveryData ) )
        logger.error( 'Host already created' )

        # look for online status ...
        #
        status = @redis.status( { :short => host } )

        logger.debug( status )
        logger.debug( status.class.to_s )

        status = status.dig(:status)

        if( status != nil || status != Storage::RedisClient::OFFLINE )

          logger.debug( 'set host status to ONLINE' )
          status = @redis.setStatus( { :short => host, :status => Storage::RedisClient::ONLINE } )
        end

        return {
          :status  => 409, # 409 Conflict
          :message => 'Host already created'
        }

      end

      # -----------------------------------------------------------------------------------

      # block this job..
      #
      @jobs.add( { :ip => ip, :short => short, :fqdn => fqdn } )

      # get customized configurations of ports and services
      #
      logger.debug( 'ask for custom configurations' )
      if( @database != nil )
        ports    = @database.config( { :short => short, :key => 'ports' } )
        services = @database.config( { :short => short, :key => 'services' } )

        logger.debug( "database: #{ports}" )
        logger.debug( "database: #{services}" )
      end

      ports    = @redis.config( { :short => short, :key => 'ports' } )
      services = @redis.config( { :short => short, :key => 'services' } )

      logger.debug( "redis: #{ports}" )
      logger.debug( "redis: #{services}" )

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

      open = false

      # check open ports and ask for application behind open ports
      #
      ports.each do |p|

        open = Utils::Network.portOpen?( fqdn, p )

        logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

        if( open == true )

          names = self.discoverApplication( { :fqdn => fqdn, :port => p } )

          logger.debug( "discovered services: #{names}" )

          if( names != nil )

            names.each do |name|
              discoveredServices.merge!( { name => { 'port' => p } } )
            end

          end

        end

      end

      # TODO
      # merge discovered services with additional services
      #
      if( services.is_a?( Array ) && services.count >= 1 )

        services.each do |s|

          serviceData = @serviceConfig.dig( 'services', s )

          if( serviceData != nil )

            discoveredServices[s] ||= serviceData.filter( 'port' )
          end
        end

      end


      # merge discovered services with cm-services.yaml
      #
      discoveredServices = self.createHostConfig( discoveredServices )

      if( @database != nil )
        result    = @database.createDiscovery( { :short => short, :data => discoveredServices } )
        logger.debug( "database: #{result}" )
      end

      result = @redis.createDiscovery( {
        :short    => short,
        :data     => discoveredServices
      } )
      logger.debug( "redis: #{result}" )

      logger.debug( 'set host status to ONLINE' )
      if( @database != nil )
        result    = @database.setStatus( { :short => host, :status => Storage::MySQL::ONLINE } )
        logger.debug( "database: #{result}" )
      end
      status = @redis.setStatus( { :short => host, :status => Storage::RedisClient::ONLINE } )
      logger.debug( "redis: #{result}" )

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

      @jobs.del( { :ip => ip, :short => short, :fqdn => fqdn } )

  #     logger.debug( @redis.nodes() )

      return {
        :status   => 200,
        :message  => 'Host successful created',
        :services => services
      }

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

        nodes = @redis.nodes()

        return nodes

      else

        # get a DNS record
        #
        ip, short, fqdn = self.nsLookup( host )

        if( @database != nil )
          discoveryData    = @database.discoveryData( { :short => short } )
          logger.debug( "database: #{discoveryData}" )
        end

        discoveryData = @redis.discoveryData( { :short => short } )
        logger.debug( "database: #{discoveryData}" )

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

          if( @database != nil )
            result    = @database.status( { :short => short } )
            logger.debug( "database: #{result}" )
          end

          result      = @redis.status( { :short => short } )
          logger.debug( "redis: #{result}" )

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
