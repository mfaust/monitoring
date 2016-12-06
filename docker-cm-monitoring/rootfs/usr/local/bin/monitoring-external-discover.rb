#!/usr/bin/ruby
#
# 06.12.2016 - Bodo Schulz
#
#
# v0.0.1

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'yaml'
require 'fileutils'
require 'resolve/hostname'
require_relative 'monitoring'

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class Client

    def initialize( settings = {} )

      @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'

      logFile         = sprintf( '%s/monitoring.log', @logDirectory )

      file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
      file.sync       = true
      @log            = Logger.new( file, 'weekly', 1024000 )
  #    @log = Logger.new( STDOUT )
      @log.level      = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter  = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      @configFile = '/etc/cm-monitoring.yaml'

      self.readConfigFile()

      version              = '0.0.1'
      date                 = '2016-12-06'

      @log.info( '-----------------------------------------------------------------' )
      @log.info( ' CoreMedia - External Discovery Service' )
      @log.info( "  Version #{version} (#{date})" )
      @log.info( '  Copyright 2016 Coremedia' )
      @log.info( '-----------------------------------------------------------------' )
      @log.info( '' )

      sleep(2)

    end


    def readConfigFile()

      config = YAML.load_file( @configFile )

      @logDirectory  = config['logDirectory']      ? config['logDirectory']      : '/tmp/log'
      @cacheDir      = config['cacheDirectory']    ? config['cacheDirectory']    : '/tmp/cache'

      @discoveryHost = config['discovery']['host'] ? config['discovery']['host'] : 'localhost'
      @discoveryPort = config['discovery']['port'] ? config['discovery']['port'] : 2222

    end


    def client()

      uri = URI( sprintf( 'http://%s:%d', @discoveryHost, @discoveryPort ) )

      response = nil

      begin
        Net::HTTP.start( uri.host, uri.port ) do |http|
          request = Net::HTTP::Get.new( uri.request_uri )

          request.add_field('Content-Type', 'application/json')

          response     = http.request( request )
          responseCode = response.code.to_i

          if( responseCode == 200 )

            responseBody  = JSON.parse( response.body )
            dashboards    = responseBody.collect { |item| item['uri'] }

            return( dashboards )

          # TODO
          # Errorhandling
          #if( responseCode != 200 )
          elsif( responseCode != 200 )
            # 200 – Created
            # 400 – Errors (invalid json, missing or invalid fields, etc)
            # 401 – Unauthorized
            # 412 – Precondition failed
            @log.error( sprintf( ' [%s] ', responseCode ) )
            @log.error( sprintf( '  %s  ', response.body ) )
          end
        end
      rescue Exception => e
        @log.error( e )
        @log.error( e.backtrace )

        status  = 404
        message = sprintf( 'internal error: %s', e )
      end

    end


    def run()


    end

  end
end

e = ExternalDiscovery::Client.new()

e.run()


# EOF
