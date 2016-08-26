#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.1
# -----------------------------------------------------------------------------

require 'socket'
require 'timeout'
require 'logger'
require 'json'
require 'fileutils'
# require 'resolv-replace.rb'
require 'net/http'
require 'uri'

require_relative 'tools'

# -------------------------------------------------------------------------------------------------------------------

class ServiceDiscovery

  attr_reader :status, :message, :services

  def initialize( settings = {} )

    @logDirectory   = settings['log_dir']      ? settings['log_dir']      : '/tmp'
    @cacheDirectory = settings['cache_dir']    ? settings['cache_dir']    : '/var/tmp/monitoring'
    @jolokiaHost    = settings['jolokia_host'] ? settings['jolokia_host'] : 'localhost'
    @jolokiaPort    = settings['jolokia_port'] ? settings['jolokia_port'] : 8080

    logFile = sprintf( '%s/service-discovery.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    if( ! File.exist?( @cacheDirectory ) )
      Dir.mkdir( @cacheDirectory )
    end

    @information = Hash.new()

    @known_ports = [
      3306,     # mysql
      5432,     # postrgres
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

    version              = '1.0.1'
    date                 = '2016-08-12'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CM Service Discovery' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( "  cache directory located at #{@cacheDirectory}" )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

  end


  def configure( options = {} )

    if( options )
      config = JSON.pretty_generate( options )

      @log.debug( config )
    end

  end


  def jolokiaIsAvailable?()

    # if our jolokia proxy available?
    if( ! portOpen?( @jolokiaHost, @jolokiaPort ) )
      @log.error( 'jolokia service is not available!' )
      @log.error( 'skip service discovery' )
      return false
    end

    return true
  end


  def discoverApplication( host, port )

    @log.debug( sprintf( 'check port %s for service ', port.to_s  ) )

    service = ''

    if( port == 3306 or port == 5432 or port == 28017 )

      case port
      when 3306
        service = 'mysql'
      when 5432
        service = 'postgres'
      when 28017
        service = 'mongodb'
      end
    else

      uri          = URI.parse( sprintf( 'http://%s:%s', @jolokiaHost, @jolokiaPort ) )
      http         = Net::HTTP.new( uri.host, uri.port )

      request      = Net::HTTP::Post.new( '/jolokia/' )
      request.add_field('Content-Type', 'application/json')

      # hash for the NEW Port-Schema
      hash = {
        :type => "read",
        :mbean => "java.lang:type=Runtime",
        :attribute => [
          "ClassPath"
        ],
        :target => {
          :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
        }
      }
      request.body = JSON.generate( hash )

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        @log.error( error )

        case error
        when Errno::ECONNREFUSED
          @log.error( 'connection refused' )
        when Errno::ECONNRESET
          @log.error( 'connection reset' )
        end
      else

        body         = JSON.parse( response.body )

        if( body['status'] == 200 )

          classPath  = body['value']['ClassPath'] ? body['value']['ClassPath'] : nil

          if( classPath.include?( 'cm7-tomcat-installation' ) )

            @log.debug( 'old style' )

            hash = {
              :type => "read",
              :mbean => "Catalina:type=Engine",
              :attribute => [
                'baseDir'
              ],
              :target => {
                :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
              }
            }

            request.body = JSON.generate( hash )
            response     = http.request( request )
            body         = JSON.parse( response.body )

            if( body['status'] == 200 )

              baseDir   = body['value']['baseDir'] ? body['value']['baseDir'] : nil

              regex = /
                ^                           # Starting at the front of the string
                (.*)                        #
                \/cm7-                      #
                (?<service>.+[a-zA-Z0-9-])  #
                (.*)-tomcat                 #
                $
              /x

              parts           = baseDir.match( regex )
            end

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

            parts           = classPath.match( regex )
          end

          if( parts )
            service         = "#{parts['service']}".strip.tr( '. ', '' )

            @log.debug( sprintf( '  => %s', service ) )
          else
            @log.error( 'unknown' )
          end

        else
          # uups
        end

      end

      # normalize service names
      case service
      when 'cms'
        service = 'content-management-server'
      when 'mls'
        service = 'master-live-server'
      when 'rls'
        service = 'replication-live-server'
      when 'wfs'
        service = 'workflow-server'
      when 'delivery'
        service = 'cae-live-1'
      when 'solr'
        service = 'solr-master'
      end

    end

    # services.merge!( { name => { 'port' => p } } )

    return service
  end

  # delete the directory with all files inside
  def deleteHost( host )

    @log.info( sprintf( 'delete Host \'%s\'',  host ) )
    dir_path  = sprintf( '%s/%s', @cacheDirectory, host )

    if( File.exist?( dir_path ) )

      FileUtils.rm_r( dir_path )

      @status  = 200
      @message = 'Host successful removed'
    else

      @status  = 400
      @message = 'Hosts not exists'
    end

    return {
      'status'  => @status,
      'message' => @message
    }

  end

  # add Host and discovery applications
  def addHost( host, ports = [], force = false )

    # first, we check if our jolokia accessable
    if( ! jolokiaIsAvailable?() )

      @status  = 400
      @message = 'Jolokia not available'

      return {
        'status'  => @status,
        'message' => @message
      }
    end

    ip = dnsResolve( host )

    # second, if the that we whant monitored, available
    if( isRunning?( ip ) == false )

      @status  = 400
      @message = 'Host not available'

      return {
        'status'  => @status,
        'message' => @message
      }
    end

    # force delete
    if( force == true )

      @log.info( 'use force mode' )
      self.deleteHost( host )
    end

    dir_path  = sprintf( '%s/%s', @cacheDirectory, host )
    file_name = 'discovery.json'

    if( !File.exist?( dir_path ) )
      Dir.mkdir( dir_path )
    end

    # our default known ports
    if( ports.empty? )
      ports = @known_ports
    end

    if( File.exist?( sprintf( '%s/%s', dir_path, file_name ) ) == true )

      @status  = 409
      @message = 'Host already created'

      return {
        'status'  => @status,
        'message' => @message
      }
    end

    discover = Hash.new()
    services = Hash.new()

    open = false

    ports.each do |p|

      open = portOpen?( ip, p )

      @log.debug( sprintf( 'Host: %s | Port: %s   - status %s', host, p, open ) )

      if( open == true )

        name = self.discoverApplication( host, p )

        services.merge!( { name => { 'port' => p } } )

      end

    end

    File.open( sprintf( '%s/%s', dir_path, file_name ) , 'w' ) {|f| f.write( JSON.pretty_generate( services ) ) }

    @status  = 201
    @message = 'Host successful created'
    @services = services

    return {
      'status'  => @status,
      'message' => @message
    }
  end


  def refreshHost( host )

    ip = dnsResolve( host )

    # second, if the that we whant monitored, available
    if( isRunning?( ip ) == false )

      @status  = 400
      @message = 'Host not available'

      return {
        'status'  => @status,
        'message' => @message
      }
    end


  end


  def listHosts( host = nil )

    hosts = Array.new()

    if( host == nil )

      Dir.chdir( @cacheDirectory )
      Dir.glob( "**" ) do |f|

        if( FileTest.directory?( f ) )
          hosts.push( hostInformation( f, File.basename( f ) ) )
        end
      end

      hosts.sort!{ |a,b| a['name'] <=> b['name'] }

      @status  = 200
      @message = hosts

      return {
        'status' => @status,
        'hosts'  => @message
      }

    else

      dir_path  = sprintf( '%s/%s', @cacheDirectory, host )
      file_name = 'discovery.json'

      file      = sprintf( '%s/%s', dir_path, file_name )

      if( File.exist?( file ) == true )

        data = File.read( file )

        h              = hostInformation( file, File.basename( dir_path ) )
        h['services' ] = JSON.parse( data )

        @status   = 200
        @message  = h
        @services = h['services']

        return {
          'status' => @status,
          'hosts'  => @message
        }

      else

        @status  = 404
        @message = 'No discovery File found'

        return {
          'status' => @status,
          'hosts'  => @message
        }
      end

    end
  end


  def hostInformation( file, host )

    status = isRunning?( host )
    age    = File.mtime( file ).strftime("%Y-%m-%d %H:%M:%S")

    return {
      host => {
        'status' => status ? 'online' : 'offline',
        'created' => age
      }
    }

  end

end

