#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.3.1
# -----------------------------------------------------------------------------

require 'socket'
require 'timeout'
# require 'logger'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'
require 'sqlite3'

require_relative 'logging'
require_relative 'tools'
require_relative 'storage'

# -------------------------------------------------------------------------------------------------------------------

class ServiceDiscovery

#   attr_reader :status, :message, :services

  include Logging

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
      49099
    ]

    @logDirectory      = settings[:logDirectory]      ? settings[:logDirectory]        : '/var/log/monitoring'
    @cacheDirectory    = settings[:cacheDirectory]    ? settings[:cacheDirectory]      : '/var/cache/monitoring'
    @jolokiaHost       = settings[:jolokiaHost]       ? settings[:jolokiaHost]         : 'localhost'
    @jolokiaPort       = settings[:jolokiaPort]       ? settings[:jolokiaPort]         : 8080
    @serviceConfig     = settings[:serviceConfigFile] ? settings[:serviceConfigFile]   : nil
    @scanPorts         = settings[:scanPorts]         ? settings[:scanPorts]           : ports

    if( ! File.exist?( @cacheDirectory ) )
      Dir.mkdir( @cacheDirectory )
    end

    @db = Storage::Database.new()

    version              = '1.3.3'
    date                 = '2017-01-03'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Service Discovery' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016 Coremedia' )
    logger.info( "  cache directory located at #{@cacheDirectory}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    self.readConfigurations()
  end


  def readConfigurations()

    # read Service Configuration
    #
    logger.info( 'read defines of Services Properties' )

    if( @serviceConfig == nil )
      puts 'missing service config file'
      logger.error( 'missing service config file' )
      exit 1
    end

    begin

      if( File.exist?( @serviceConfig ) )
        @serviceConfig      = YAML.load_file( @serviceConfig )
      else
        logger.error( sprintf( 'Config File %s not found!', @serviceConfig ) )
        exit 1
      end

    rescue Exception

      logger.error( 'wrong result (no yaml)')
      logger.error( "#{$!}" )
      exit 1
    end

  end


  def configure( options = {} )

    if( options )
      config = JSON.pretty_generate( options )

      logger.debug( config )
    end

  end


  def jolokiaIsAvailable?()

    # if our jolokia proxy available?
    if( ! portOpen?( @jolokiaHost, @jolokiaPort ) )
      logger.error( 'jolokia service is not available!' )
      logger.error( 'skip service discovery' )
      return false
    end

    return true
  end


  def discoverApplication( host, port )

    logger.debug( 'discover Application ...' )

    services = Array.new

    if( port == 3306 || port == 5432 || port == 9100 || port == 28017 )

      case port
      when 3306
        services.push('mysql')
      when 5432
        services.push('postgres')
      when 9100
        services.push('node_exporter')
      when 28017
        services.push('mongodb')
      end
    else

      uri          = URI.parse( sprintf( 'http://%s:%s', @jolokiaHost, @jolokiaPort ) )
      http         = Net::HTTP.new( uri.host, uri.port )

      request      = Net::HTTP::Post.new( '/jolokia/' )
      request.add_field('Content-Type', 'application/json')

      h     = Hash.new()
      array = Array.new()

      # hash for the NEW Port-Schema
      # since cm160x every application runs in his own container with unique port schema

      targetUrl = sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )

      array << {
        :type      => "read",
        :mbean     => "java.lang:type=Runtime",
        :attribute => [ "ClassPath" ],
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      array << {
        :type      => "read",
        :mbean     => "Catalina:type=Manager,context=*,host=*",
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      array << {
        :type      => "read",
        :mbean     => "Catalina:type=Engine",
        :attribute => [ 'baseDir', 'jvmRoute' ],
        :target    => { :url => targetUrl },
        :config    => { "ignoreErrors" => true, "ifModifiedSince" => true, "canonicalNaming" => true }
      }

      body = JSON.pretty_generate( array )

      logger.debug( body )

      request.body = body

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        logger.error( error )

        case error
        when Errno::ECONNREFUSED
          logger.error( 'connection refused' )
        when Errno::ECONNRESET
          logger.error( 'connection reset' )
        end

      else

        body         = JSON.parse( response.body )

        logger.debug( JSON.pretty_generate( body ) )

        # #1 == Runtime
        runtime = body[0]
        # #2  == Manager
        manager = body[1]
        # #3  == engine
        engine = body[2]

        if( runtime['status'] && runtime['status'] == 200 )

          value = runtime['value'] ? runtime['value'] : nil

          if( value != nil )

            classPath  = value['ClassPath'] ? value['ClassPath'] : nil

            if( classPath.include?( 'cm7-tomcat-installation' ) )

              logger.debug( 'found pre cm160x Portstyle (‎possibly cm7.x)' )
              value = manager['value'] ? manager['value'] : nil

              regex = /context=(.*?),/
              value.each do |context,v|

                part = context.match( regex )

                if( part != nil && part.length > 1 )

                  appName = part[1].gsub!( '/', '' )

                  if( appName == 'manager' )
                    # skip 'manager'
                    next
                  end

                  logger.debug( sprintf( ' - ‎recognized application: %s', appName ) )
                  services.push( appName )
                end
              end

              logger.debug( services )

              # coremedia = cms, mls, rls?
              # caefeeder = caefeeder-preview, cae-feeder-live?
              if( ( services.include?( 'coremedia' ) ) || ( services.include?( 'caefeeder' ) ) )

                value = engine['value'] ? engine['value'] : nil

                if( engine['status'].to_i == 200 )

                  baseDir = value['baseDir'] ? value['baseDir'] : nil

                  regex = /
                    ^                           # Starting at the front of the string
                    (.*)                        #
                    \/cm7-                      #
                    (?<service>.+[a-zA-Z0-9-])  #
                    (.*)-tomcat                 #
                    $
                  /x

                  parts = baseDir.match( regex )

                  if( parts )
                    service = parts['service'].to_s.strip.tr('. ', '')
                    services.delete( "coremedia" )
                    services.delete( "caefeeder" )
                    services.push( service )

                    logger.debug( sprintf( '  => %s', service ) )
                  else
                    logger.error( 'unknown error' )
                    logger.error( parts )
                  end
                else
                  logger.error( sprintf( 'response status %d', engine['status'].to_i ) )
                end
              end

              # blueprint = cae-preview or delivery?editor
              if( services.include?( 'blueprint' ) )

                value = engine['value'] ? engine['value'] : nil

                if( engine['status'].to_i == 200 )

                  jvmRoute = value['jvmRoute'] ? value['jvmRoute'] : nil

                  if( ( jvmRoute != nil ) && ( jvmRoute.include?( 'studio' ) ) )
                    services.delete( "blueprint" )
                    services.push( "cae-preview" )
                  else
                    services.delete( "blueprint" )
                    services.push( "delivery" )
                  end
                else
                  logger.error( sprintf( 'response status %d', engine['status'].to_i ) )
                end
              end

            # cm160x - or all others
            else

              regex = /
                ^                           # Starting at the front of the string
                (.*)                        #
                \/coremedia\/               #
                (?<service>.+[a-zA-Z0-9-])  #
                \/current                   #
                (.*)                        #
                $
              /x

              parts = classPath.match( regex )

              if( parts )
                service = parts['service'].to_s.strip.tr('. ', '')
                services.push( service )

                logger.debug( sprintf( '  => %s', service ) )
              else
                logger.error( 'unknown error' )
                logger.error( parts )
              end
            end

          end
        end

      end

      # normalize service names
      services.map! {|service|

        case service
          when 'cms'
            'content-management-server'
          when 'mls'
            'master-live-server'
          when 'rls'
            'replication-live-server'
          when 'wfs'
            'workflow-server'
          when 'delivery'
            'cae-live-1'
          when 'solr'
            'solr-master'
          when 'contentfeeder'
            'content-feeder'
          when 'workflow'
            'workflow-server'
          else
            service
        end
      }

    end

#    logger.debug( "final services #{services}" )

    return services
  end


  # merge hashes of configured (cm-service.yaml) and discovered data (discovery.json)
  def createHostConfig( data )

    data.each do |d,v|

      # merge data between discovered Services and our base configuration,
      # the dicovered ports are IMPORTANT
      if( @serviceConfig['services'][d] )
        data[d].merge!( @serviceConfig['services'][d] ) { |key, port| port }

        port       = data[d]['port']      ? data[d]['port']      : nil
        port_http  = data[d]['port_http'] ? data[d]['port_http'] : nil

        if( port != nil && port_http != nil )
          data[d]['port_http'] = ( port - 19 )
        end

      else
        logger.debug( sprintf( 'missing entry \'%s\'', d ) )
      end
    end

    return data

  end

  # delete the directory with all files inside
  def deleteHost( host )

    logger.info( sprintf( 'delete Host \'%s\'',  host ) )

    @db.removeDNS( { :ip => host, :short => host, :long => host } )

    status  = 400
    message = 'Host not in Monitoring'

    cacheDirectory  = sprintf( '%s/%s', @cacheDirectory, host )

    if( Dir.exist?( cacheDirectory ) )

      FileUtils.rm_r( Dir.glob( sprintf( '%s/*', cacheDirectory ) ) )
      FileUtils.rmdir( cacheDirectory, :verbose => true )

#      # hmmm ... prepare our config.json or not?
#      ['discovery.json','host.json','mergedHostData.json'].each do |f|
#        FileUtils.rm( sprintf( '%s/%s', @cacheDirectory, f ) , :force => true )
#      end

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

#     services = options['services'] ? options['services'] : []
#     force    = options['force']    ? options['force']    : false
#
#     if( services.count != 0 )
#
#       logger.info( 'Use additional services:' )
#       logger.info( "  #{services}" )
#     end

    # build Host CacheDirectory (if not exitsts)
    cacheDirectory  = sprintf( '%s/%s', @cacheDirectory, host )

    if( !File.exist?( cacheDirectory ) )
      Dir.mkdir( cacheDirectory )
    end

    discoveryFileName = 'discovery.json'

    if( File.exist?( sprintf( '%s/%s', cacheDirectory, discoveryFileName ) ) == true )

      status  = 409
      message = 'Host already created'

      return {
        :status  => status,
        :message => message
      }
    end

    # first, we check if our jolokia accessable
    if( ! jolokiaIsAvailable?() )

      status  = 400
      message = 'Jolokia not available'

      return {
        :status  => status,
        :message => message
      }
    end

    hostInfo = hostResolve( host )

    ip            = hostInfo[:ip]    ? hostInfo[:ip]    : nil
    shortHostName = hostInfo[:short] ? hostInfo[:short] : nil
    longHostName  = hostInfo[:long]  ? hostInfo[:long]  : nil

    # second, if the that we whant monitored, available
    if( isRunning?( ip ) == false )

      status  = 400
      message = 'Host not available'

      return {
        :status  => status,
        :message => message
      }
    end

    @db.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )

    ports = @db.config( { :ip => ip, :short => shortHostName, :long => longHostName, :key => "ports" } )

    if( ports != false )
      ports = ports.dig( shortHostName, 'ports' )
    else
      # our default known ports
      ports = @scanPorts
    end

    logger.debug( "use ports: #{ports}" )

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = portOpen?( longHostName, p )

      logger.debug( sprintf( 'Host: %s | Port: %s   - status %s', host, p, open ) )

      if( open == true )

        names = self.discoverApplication( host, p )

        names.each do |name|
          services.merge!( { name => { 'port' => p } } )
        end

      end

    end

    # merge discovered services with cm-services.yaml
    services = self.createHostConfig( services )

    # TODO
    # hook to create database entry
    File.open( sprintf( '%s/%s', cacheDirectory, discoveryFileName ) , 'w' ) { |f| f.write( JSON.pretty_generate( services ) ) }

    logger.debug( JSON.pretty_generate( services ) )

    dns = @db.dnsData( { :short => shortHostName } )

    if( dns == nil )
      logger.debug( 'no data for ' + shortHostName )
    else
      dnsId        = dns[ :id ]
      dnsIp        = dns[ :ip ]
      dnsShortname = dns[ :shortname ]
      dnsLongname  = dns[ :longname ]
      dnsCreated   = dns[ :created ]
      dnsChecksum  = dns[ :checksum ]

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

    hostInfo = hostResolve( host )
    ip       = hostInfo[:ip] ? hostInfo[:ip] : nil

    # second, if the that we want monitored, available
    if( isRunning?( ip ) == false )

      status  = 400
      message = 'Host not available'
    end

    return {
      :status  => status,
      :message => message
    }

  end


  def listHosts( host = nil )

    hosts = Array.new()

    if( host == nil )

      data = @db.discoveryData()



      Dir.chdir( @cacheDirectory )
      Dir.glob( "**" ) do |f|

        if( FileTest.directory?( f ) )
          hosts.push( hostInformation( f, File.basename( f ) ) )
        end
      end

      hosts.sort!{ |a,b| a['name'] <=> b['name'] }

      status  = 200
      message = hosts

      return {
        :status  => status,
        :hosts   => message
      }

    else

      cacheDirectory  = sprintf( '%s/%s', @cacheDirectory, host )
      discoveryFileName = 'discovery.json'

      file      = sprintf( '%s/%s', cacheDirectory, discoveryFileName )

      if( File.exist?( file ) == true )

        data = File.read( file )

        h              = hostInformation( file, File.basename( cacheDirectory ) )
        h['services' ] = JSON.parse( data )

        status   = 200
        message  = h
        @services = h['services']

        return {
          :status  => status,
          :hosts   => message
        }

      else

        status  = 404
        message = 'No discovery File found'

        return {
          :status  => status,
          :hosts   => nil,
          :message => message
        }
      end

    end
  end


  def hostInformation( file, host )

    status   = isRunning?( host )
    age      = File.mtime( file ).strftime("%Y-%m-%d %H:%M:%S")
    services = Hash.new()

    if( file != host )
      data   = JSON.parse( File.read( file ) )

      data.each do |d,v|

        services[d.to_s] ||= {}
        services[d.to_s] = {
          :port        => v['port'],
          :description => v['description']
        }
      end
    end

    return {
      host => {
        :status   => status ? 'online' : 'offline',
        :services => services,
        :created  => age
      }
    }

  end

end

