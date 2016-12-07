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
require 'dalli'
require 'resolve/hostname'

#require_relative 'monitoring'

# -----------------------------------------------------------------------------

# Monkey patches

class Array
  def compare( comparate )
    to_set == comparate.to_set
  end
end

# -----------------------------------------------------------------------------



module ExternalDiscovery


  class Node

    attr_accessor :name, :enabled, :id, :ip, :tags

    def initialize( params = {} )

      @name    = params[:name]
      @enabled = params[:enbaled]
      @id      = params[:id]
      @ip      = params[:ip]
      @tags    = params[:tags]
    end

  end


  class DataConsumer

    attr_reader :data

    def initialize( settings )


#      @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'
#      logFile         = sprintf( '%s/monitoring.log', @logDirectory )
#      file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#      file.sync       = true
#      @log            = Logger.new( file, 'weekly', 1024000 )
      @log = Logger.new( STDOUT )
      @log.level      = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter  = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      @memcacheHost = settings[:memcacheHost] ? settings[:memcacheHost] : nil
      @memcachePort = settings[:memcachePort] ? settings[:memcachePort] : nil

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'discover',
        :expires_in => 60*2
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @log.debug( 'initialized' )

      @total = 0
      @mutex = Mutex.new
    end


    def getData()

      @data = @mutex.synchronize { self.mockupData() }

      @mc.set( 'consumer__live__data' , @data )

    end

    def mockupData()

      data = [
        {
          "enabled": "true",
          "id": "i-5f525fa7",
          "ip": "172.32.31.221",
          "name": "i-5f525fa7",
          "tags": [
            "feeder"
          ]
        },
        {
          "enabled": "true",
          "id": "i-03f0d80d",
          "ip": "172.32.31.58",
          "name": "i-03f0d80d",
          "tags": [
            "cms"
          ]
        }
      ]

      return data

    end

  end


  class Client

    def initialize( settings = {} )

#      @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'
#      logFile         = sprintf( '%s/monitoring.log', @logDirectory )
#      file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#      file.sync       = true
#      @log            = Logger.new( file, 'weekly', 1024000 )
      @log = Logger.new( STDOUT )
      @log.level      = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter  = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      @memcacheHost = settings[:memcacheHost] ? settings[:memcacheHost] : nil
      @memcachePort = settings[:memcachePort] ? settings[:memcachePort] : nil

      @configFile   = '/etc/cm-monitoring.yaml'

      self.readConfigFile()

      # add cache setting
      # eg.cache for 2 min here. default options is never expire
      memcacheOptions = {
        :compress   => true,
        :namespace  => 'discover',
        :expires_in => 60*3
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      version              = '0.0.1'
      date                 = '2016-12-06'

      @log.info( '-----------------------------------------------------------------' )
      @log.info( ' CoreMedia - External Discovery Service' )
      @log.info( "  Version #{version} (#{date})" )
      @log.info( '  Copyright 2016 Coremedia' )
      @log.info( '-----------------------------------------------------------------' )
      @log.info( '' )
    end


    def readConfigFile()

      config = YAML.load_file( @configFile )

      @logDirectory  = config.dig('logDirectory')        || '/tmp/log'
      @cacheDir      = config.dig('cacheDirectory')      || '/tmp/cache'

      @discoveryHost = config.dig( 'discovery', 'host' ) || 'localhost'
      @discoveryPort = config.dig( 'discovery', 'port' ) || 2222

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



    def compareVersions()

      @log.debug( 'compare' )

      liveData     = @mc.get( 'consumer__live__data' )     || []
      historicData = @mc.get( 'consumer__historic__data' ) || []

      @log.debug( liveData.sort     { |a,b| a[:x] <=> b[:x] } )
      @log.debug( historicData.sort { |a,b| a[:x] <=> b[:x] } )

      @log.debug( sprintf( 'live Data holds %d entries', liveData.count ) )
      @log.debug( sprintf( 'historic Data holds %d entries', historicData.count ) )

      def findUid( historic, uid )

        historic.each do |h|
          @log.debug( h.values )

          return h.select { |key, value| key.to_s.match(/^uid/) }
#          @log.debug( h.select { |key, value| key.to_s.match(/^uid/) } )
        end
      end

      if( liveData.compare( historicData ) == true )
        @log.debug( 'the same' )

        liveData.each do |k|
          @log.debug( k )
#           @log.debug( k.values )
#           @log.debug( k.values[1] )

          @log.debug( self.findUid( historicData, k.values[1] ) )

          #@log.debug( k.find_all { |a| a[:ip] == '172.32.31.58' } )
#           choices = k.select { |key, value| key.to_s.match(/^choice\d+/) }

        end

      else
        @log.debug( 'differs' )

        liveData.each do |k|
          @log.debug( k )
#          @log.debug( v )

          @log.debug( k.select { |a| a["ip"] == '172.32.31.58' } )

#           choices = k.select { |key, value| key.to_s.match(/^choice\d+/) }

        end

#         @log.debug( liveData.select { |name,v| v['ip'] == '172.32.31.58' } )




        @mc.set( 'consumer__historic__data', liveData, 60*3 )
      end

    end



    def run()

      @data   = Array.new()
      threads = Array.new()

      config = {
        :memcacheHost => @memcacheHost,
        :memcachePort => @memcachePort
      }

      consumer = DataConsumer.new( config )

      threads << Thread.new {

        consumer.getData()
      }

      threads.each {|t| t.join }

#      fork do
#
#        @data = consumer.getData()
#
#        @log.debug( @data )
#      end


      fork do
        self.compareVersions()
      end

      Process.waitall

      @log.debug( 'done' )


    end

  end


end

# ---------------------------------------------------------------------------------------

memcacheHost = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : 'localhost'
memcachePort = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : 11211

config = {
  :logDirectory => '/tmp',
  :memcacheHost => memcacheHost,
  :memcachePort => memcachePort
}

# ---------------------------------------------------------------------------------------

e = ExternalDiscovery::Client.new( config )

e.run( )


# [
#   {
#     "enabled": "true",
#     "id": "i-5f525fa7",
#     "ip": "172.32.31.221",
#     "name": "i-5f525fa7",
#     "tags": [
#       "feeder"
#     ]
#   },
#   {
#     "enabled": "true",
#     "id": "i-03f0d80d",
#     "ip": "172.32.31.58",
#     "name": "i-03f0d80d",
#     "tags": [
#       "cms"
#     ]
#   }
# ]


# EOF
