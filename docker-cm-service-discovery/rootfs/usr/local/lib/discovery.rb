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
require_relative 'message-queue'
require_relative 'storage'
require_relative 'discovery/queue'
require_relative 'discovery/discovery'

# -------------------------------------------------------------------------------------------------------------------

module ServiceDiscovery

  class Client

  include Logging

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

    @serviceConfig      = settings.dig(:configFiles, :service)

    @MQSettings = {
      :beanstalkHost  => mqHost,
      :beanstalkPort  => mqPort,
      :beanstalkQueue => @mqQueue
    }

    @scanPorts         = ports

    version             = '1.6.0'
    date                = '2017-04-11'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Service Discovery' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - jolokia      : #{jolokiaHost}:#{jolokiaPort}" )
    logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
    logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    @cache              = Cache::Store.new()

    @redis              = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
    @jolokia            = Jolokia::Client.new( { :host => jolokiaHost, :port => jolokiaPort, :path => jolokiaPath, :auth => { :user => jolokiaAuthUser, :pass => jolokiaAuthPass } } )
    @mqConsumer         = MessageQueue::Consumer.new( @MQSettings )

    self.readConfigurations()
  end


  def readConfigurations()

    # read Service Configuration
    #
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
  def createHostConfig( data )

#     logger.debug( "createHostConfig( #{data} )" )

    data.each do |d,v|

#       logger.debug( d )

      # merge data between discovered Services and our base configuration,
      # the dicovered ports are IMPORTANT
      if( @serviceConfig['services'][d] )

#         logger.debug( @serviceConfig['services'][d] )

        data[d].merge!( @serviceConfig['services'][d] ) { |key, port| port }

        port       = data.dig( d, 'port' )      # [d]['port']      ? data[d]['port']      : nil
        port_http  = data.dig( d, 'port_http' ) # [d]['port_http'] ? data[d]['port_http'] : nil

        if( port != nil && port_http != nil )
          data[d]['port_http'] = ( port - 19 )
        end

      else
        logger.debug( sprintf( 'missing entry \'%s\' in cm-service.yaml for merge with discovery data', d ) )
      end
    end

    return data

  end

  # delete the directory with all files inside
  def deleteHost( host )

    logger.info( sprintf( 'delete Host \'%s\'',  host ) )

    status  = 400
    message = 'Host not in Monitoring'

    if( @redis.removeDNS( { :short => host } ) != nil )

      status  = 200
      message = 'Host successful removed'
    end

    return {
      :status  => status,
      :message => message
    }

  end

  # add Host and discovery applications
  def addHost( host, options = {} )

    logger.info( sprintf( 'Adding host \'%s\'', host ) )

    discoveryData = @redis.discoveryData( { :short => host } )

    shortName     = discoveryData.dig(:short)

    if( shortName != nil )

      logger.error( 'Host already created' )

      return {
        :status  => 409,
        :message => 'Host already created'
      }

    end

    if( @jolokia.jolokiaIsAvailable?() == false )

      logger.error( 'jolokia service is not available!' )

      return {
        :status  => 500,
        :message => 'jolokia service is not available!'
      }
    end

    # --------------------------------------------------------------------------------------------
    # TODO
    # read first the prepared DNS data
    # second (if not valid data exists) create an valid entry ..

    hostname = sprintf( 'dns-%s', host )

    dns      = @cache.get( hostname )

#     logger.debug( dns )

    if( dns == nil )

      dns = @redis.dnsData( { :short => host } )

#       logger.debug( dns )

      if( dns.dig(:ip) == nil )

        # create DNS Information
        dns      = Utils::Network.resolv( host )

#         logger.debug( "hostResolve #{hostInfo}" )

        ip            = hostInfo.dig(:ip)
        shortHostName = hostInfo.dig(:short)
        longHostName  = hostInfo.dig(:long)

        @redis.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )
      else

#         ip            = dns.dig(:ip)
#         shortHostName = dns.dig(:shortname)
#         longHostName  = dns.dig(:longname)
      end

      @cache.set( hostname , expiresIn: 60 ) { Cache::Data.new( { 'ip': ip, 'short': shortHostName, 'long': longHostName } ) }

    end

#     logger.debug( dns )

    ip            = dns.dig(:ip)
    shortHostName = dns.dig(:shortname)
    longHostName  = dns.dig(:longname)

    logger.debug( sprintf( ' ip   %s ', ip ) )
    logger.debug( sprintf( ' host %s ', shortHostName ) )
    logger.debug( sprintf( ' fqdn %s ', longHostName ) )

    # second, if the that we whant monitored, available
    #
    if( Utils::Network.isRunning?( ip ) == false )

      logger.error( 'host not running' )

      return {
        :status  => 400,
        :message => 'Host not available'
      }
    end
    #
    # --------------------------------------------------------------------------------------------

    logger.debug( 'ask for custom configurations' )
    ports    = @redis.config( { :short => shortHostName, :key => 'ports' } )
    services = @redis.config( { :short => shortHostName, :key => 'services' } )

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

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = Utils::Network.portOpen?( longHostName, p )

      logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

      if( open == true )

        names = self.discoverApplication( longHostName, p )

        logger.debug( "discovered services: #{names}" )

        if( names != nil )

          names.each do |name|
            services.merge!( { name => { 'port' => p } } )
          end

        end

      end

    end

    # merge discovered services with cm-services.yaml
    #
    services = self.createHostConfig( services )

    @redis.createDiscovery( {
      :short    => shortHostName,
      :data     => services
    } )

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

      # create DNS Information
      hostInfo      = Utils::Network.resolv( host )

      logger.debug( "hostResolve #{hostInfo}" )

      ip            = hostInfo.dig(:ip)
      shortHostName = hostInfo.dig(:short)
      longHostName  = hostInfo.dig(:long)

      discoveryData = @redis.discoveryData( { :short => shortHostName } )

      discoveryData.each.each do |s|

        data = s.last

        if( data != nil )
          data.reject! { |k| k == 'application' }
          data.reject! { |k| k == 'template' }
        end

        services[s.first.to_sym] ||= {}
        services[s.first.to_sym] = data

      end

      status         = nil # @redis.status( { :short => shortHostName } )

      # BEHOLD
      #
      for y in 1..15

        result      = @redis.status( { :short => shortHostName } )

        if( result != nil )
          status = result
          break
        else
          logger.debug( sprintf( 'Waiting for data ... %d', y ) )
          sleep( 4 )
        end
      end

      logger.debug( JSON.pretty_generate( status ) )

      created        = status.dig( :created )

      if( created == nil )
        created      = 'unknown'
      else
        created      = Time.parse( created ).strftime( '%Y-%m-%d %H:%M:%S' )
      end

      online         = status.dig( :status )

      case online
      when Storage::RedisClient::OFFLINE, false
        status = 'offline'
      when Storage::RedisClient::ONLINE, true
        status = 'online'
      when Storage::RedisClient::DELETE
        status = 'delete'
      when Storage::RedisClient::PREPARE
        status = 'prepare'
      else
        status = 'unknown'
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
