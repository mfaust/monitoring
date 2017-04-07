#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.5.1
# -----------------------------------------------------------------------------

require 'json'
require 'yaml'
require 'fileutils'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'jolokia'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'tools'

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

    jolokiaHost        = settings.dig(:jolokiaHost) || 'localhost'
    jolokiaPort        = settings.dig(:jolokiaPort) || 8080
    jolokiaPath        = settings.dig(:jolokiaPath) || '/jolokia'
    jolokiaAuthUser    = settings.dig(:jolokiaAuthUser)
    jolokiaAuthPass    = settings.dig(:jolokiaAuthPass)
    mqHost             = settings.dig(:mqHost)      || 'localhost'
    mqPort             = settings.dig(:mqPort)      || 11300
    @mqQueue           = settings.dig(:mqQueue)     || 'mq-discover'

    redisHost          = settings.dig(:redis, :host)
    redisPort          = settings.dig(:redis, :port)

    @MQSettings = {
      :beanstalkHost  => mqHost,
      :beanstalkPort  => mqPort,
      :beanstalkQueue => @mqQueue
    }

    @serviceConfig     = settings.dig(:serviceConfigFile)
    @scanPorts         = ports

    version             = '1.5.1'
    date                = '2017-03-27'

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

    @db                 = Storage::Database.new()
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

      logger.debug( d )

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

    @redis.removeDNS( { :ip => host, :short => host, :long => host } )

    if( @db.removeDNS( { :ip => host, :short => host, :long => host } ) != nil )

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

    logger.debug( @redis.discoveryData( { :ip => host, :short => host, :long => host } ) )

    if( @db.discoveryData( { :ip => host, :short => host, :long => host } ) != nil )

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

    # create DNS Information
    hostInfo      = Utils::Network.resolv( host )

    logger.debug( "hostResolve #{hostInfo}" )

    ip            = hostInfo.dig(:ip)
    shortHostName = hostInfo.dig(:short)
    longHostName  = hostInfo.dig(:long)

    logger.debug( sprintf( 'ping ip %s if running', ip ) )

    # second, if the that we whant monitored, available
    if( Utils::Network.isRunning?( ip ) == false )

      logger.error( 'host not running' )
      logger.debug( hostInfo )

      return {
        :status  => 400,
        :message => 'Host not available'
      }
    end

    @redis.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )

    ports    = @redis.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "ports" } )
    services = @redis.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "services" } )

    logger.debug( "redis  ports   : #{ports}" )
    logger.debug( "redis  services: #{services}" )

    @db.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )

    ports    = @db.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "ports" } )
    services = @db.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "services" } )

    if( ports != false )
      ports = ports.dig( shortHostName, 'ports' )
    else
      # our default known ports
      ports = @scanPorts
    end

    logger.debug( "use ports: #{ports}" )
    logger.debug( "additional services: #{services}" )

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = Utils::Network.portOpen?( longHostName, p )

      logger.debug( sprintf( 'Host: %s | Port: %s   %s', host, p, open ? 'open' : 'closed' ) )

      if( open == true )

        names = self.discoverApplication( host, p )

        logger.debug( "discovered services: #{names}" )

        if( names != nil )

          names.each do |name|
            services.merge!( { name => { 'port' => p } } )
          end

        end

      end

    end

    # merge discovered services with cm-services.yaml
    services = self.createHostConfig( services )

    logger.debug( @redis.dnsData( { :ip => ip, :short => shortHostName } ) )

    dns      = @db.dnsData( { :ip => ip, :short => shortHostName } )

    if( dns == nil )

      logger.debug( 'no DNS data for ' + shortHostName )
    else

      dnsId        = dns[ :id ]
      dnsIp        = dns[ :ip ]
      dnsShortname = dns[ :shortname ]
      dnsLongname  = dns[ :longname ]
      dnsCreated   = dns[ :created ]
      dnsChecksum  = dns[ :checksum ]

      @redis.createDiscovery( {
        :short    => dnsShortname,
        :data     => services
      } )

      @db.createDiscovery( {
        :id       => dnsId,
        :ip       => dnsIp,
        :short    => dnsShortname,
        :checksum => dnsChecksum,
        :data     => services
      } )

    end

    status  = 200
    message = 'Host successful created'

    @services = services

    return {
      :status  => status,
      :message => message
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

    hosts    = Array.new()
    result   = Hash.new()
    services = Hash.new()

    if( host == nil )

      logger.info( 'TODO - use Database insteed of File - ASAP' )
    else

      logger.debug( @redis.discoveryData( { :ip => host, :short => host } ) )

      discoveryData  = @db.discoveryData( { :ip => host, :short => host } )

      if( discoveryData == nil )

        return {
          :status   => 404,
          :message  => 'no host found'
        }

      end

      hostServices   = discoveryData.dig( host )

      hostServices.each do |s|

        s.last.dig(:data).reject! { |k| k == :application }

        services[s.first.to_sym] ||= {}
        services[s.first.to_sym] = s.last.dig(:data)

      end

      logger.debug( @redis.status( { :ip => host, :short => host } ) )

      status         = @db.status( { :ip => host, :short => host } )

      created        = status.dig( :created )
      created        = Time.parse( created ).strftime( '%Y-%m-%d %H:%M:%S' )

      online         = status.dig( :status )

      case online
      when 0
        status = 'offline'
      when 1
        status = 'online'
      when 98
        status = 'delete'
      when 99
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

    end

    return result


    # CODE are OBSOLETE

#     if( host == nil )
#
#       data = @db.discoveryData()
#
#       Dir.chdir( @cacheDirectory )
#       Dir.glob( "**" ) do |f|
#
#         if( FileTest.directory?( f ) )
#           hosts.push( hostInformation( f, File.basename( f ) ) )
#         end
#       end
#
#       hosts.sort!{ |a,b| a['name'] <=> b['name'] }
#
#       status  = 200
#       message = hosts
#
#       return {
#         :status  => status,
#         :hosts   => message
#       }
#
#     else
#
#       cacheDirectory  = sprintf( '%s/%s', @cacheDirectory, host )
#       discoveryFileName = 'discovery.json'
#
#       file      = sprintf( '%s/%s', cacheDirectory, discoveryFileName )
#
#       if( File.exist?( file ) == true )
#
#         data = File.read( file )
#
#         h              = hostInformation( file, File.basename( cacheDirectory ) )
#         h['services' ] = JSON.parse( data )
#
#         status   = 200
#         message  = h
#         @services = h['services']
#
#         return {
#           :status  => status,
#           :hosts   => message
#         }
#
#       else
#
#         status  = 404
#         message = 'No discovery File found'
#
#         return {
#           :status  => status,
#           :hosts   => nil,
#           :message => message
#         }
#       end
#
#     end
  end

  # OBSOLETE
#   def hostInformation( file, host )
#
#
#     status   = isRunning?( host )
#     age      = File.mtime( file ).strftime("%Y-%m-%d %H:%M:%S")
#     services = Hash.new()
#
#     if( file != host )
#
#       data   = JSON.parse( File.read( file ) )
#
#       data.each do |d,v|
#
#         services[d.to_s] ||= {}
#         services[d.to_s] = {
#           :port        => v['port'],
#           :description => v['description']
#         }
#       end
#     end
#
#     return {
#       host => {
#         :status   => status ? 'online' : 'offline',
#         :services => services,
#         :created  => age
#       }
#     }
#
#   end

end

end