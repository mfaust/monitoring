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
require 'rest-client'

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

      return @data # @mc.set( 'consumer__live__data' , @data )

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


    def mockupData()

      data = [
        {
          "ip": "172.32.22.201",
          "name": "cosmos-develop-service-jumphost",
          "state": "running",
          "tags": {
            "customer": "cosmos",
            "environment": "develop",
            "instance_type": "t2.medium",
            "instance_vpc": "vpc-ff36c899",
            "tier": "service"
          },
          "uid": "i-0388354ec53784031"
        },
        {
          "ip": "172.32.31.56",
          "name": "cosmos-develop-management-cms",
          "state": "running",
          "tags": {
            "customer": "cosmos",
            "environment": "develop",
            "instance_type": "t2.large",
            "instance_vpc": "vpc-ff36c899",
            "tier": "management"
          },
          "uid": "i-0439acb7468bb04d8"
        },
        {
          "ip": "10.2.14.156",
          "name": "monitoring-16-01.coremedia.vm",
          "state": "running",
          "uid": "b595dd68-66d6-42eb-a9ea-894d526c4f14",
          "tags": [
            "customer": "moebius"
          ]
        }
      ]


      return data

    end

  end


  class NetworkClient

    def initialize( settings )

      @host = settings[:host] ? settings[:host] : 'localhost'
      @port = settings[:port] ? settings[:port] : 80

      @log = Logger.new( STDOUT )
      @log.level      = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter  = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      @log.debug( @host )
      @log.debug( @port )

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }

    end


    def fetch( path = '/' )

      # set timeouts
      openTimeout = 2
      readTimeout = 8
      response    = []

      url = sprintf( 'http://localhost%s', path )

      @log.debug( url )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )

      begin
        data   = restClient.get( @headers ).body
        data   = JSON.parse( data )

        return data
#        @log.debug( data )

      rescue Exception => e

        @log.error( e )

        return nil
      end

    end


    def post()




    end


  end







  class Client

    def initialize( settings = {} )

      @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'

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

#      @configFile   = '/etc/cm-monitoring.yaml'
#
#      self.readConfigFile()

      # add cache setting
      # eg.cache for 2 min here. default options is never expire
      memcacheOptions = {
        :compress   => true,
        :namespace  => 'discover'
##        :expires_in => 60*3
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


    def compareVersions()

      @log.debug( 'compare' )

      liveData     = @data
      historicData = @mc.get( 'consumer__historic__data' ) || []

#       liveData.sort!     { |a,b| a[:x] <=> b[:x] }
#       historicData.sort! { |a,b| a[:x] <=> b[:x] }

      liveDataCount     = liveData.count
      historicDataCount = historicData.count

      @log.debug( liveData )
      @log.debug( historicData )

      @log.info( sprintf( 'live Data holds %d entries'    , liveDataCount ) )
      @log.info( sprintf( 'historic Data holds %d entries', historicDataCount ) )

      @log.debug( '------------------------------------------------------------' )

      def findUid( historic, uid )

        @log.debug( sprintf( 'findUid %s', uid ) )

        f = {}

        historic.each do |h|

          f = h.select { |key, value| key.to_s.match(/^id/) }

          if( f[:id].to_s == uid )
            f = h
            break
          else
            f = {}
          end
        end

        return f
      end


      options = {
        :host => 'localhost',
        :port => 80
      }

      net = NetworkClient.new( options )

      hosts = net.fetch( '/api/v2/host' )

      @log.debug( hosts )

      if( historicDataCount.to_i == 0 )

        @log.info( 'no historic datas found' )

        newArray = Array.new()

        # add all founded nodes

        liveData.each do |l|

          uid     = l[:uid]     ? l[:uid]     : 'unset'
          ip      = l[:ip]      ? l[:ip]      : 'unset'
          name    = l[:name]    ? l[:name]    : 'unset'
          tags    = l[:tags]    ? l[:tags]    : []

          @log.info( sprintf( '  get information about %s', ip ) )

          result = net.fetch( sprintf( '/api/v2/host/%s', ip ) )

          if( result != nil )

          # get node data
#           result = m.listHost( ip )

            @log.debug( result )

            discoveryStatus = result.dig( ip, 'discovery', 'status' )

            @log.debug( discoveryStatus )

            # not exists
            if( discoveryStatus == 404 )

              @log.info( '  host not in monitoring ... try to add' )

              # add to monitoring
              d = JSON.generate( {
                :discovery  => true,
                :icinga     => false,
                :grafana    => false,
                :annotation => true,
                :tags       => tags
              } )

              @log.debug( d )

#               result = m.addHost( ip, d )

#               @log.debug( result )

#               discoveryStatus = result.dig( :status )
#               discoveryMessage = result.dig( :message )

#               if( discoveryStatus == 400 )
#                 @log.error( sprintf( '  => %s', discoveryMessage ) )
#               else
#                 # successful
#                 newArray << l
#
#               end
            end

          end
        end

        @log.debug( newArray )
      end

#       if( liveData.compare( historicData ) == true )
#
#         @log.debug( 'the same' )
#
#       else
#         @log.debug( 'differs' )
#
#         historicData.each do |h|
#           @log.debug( h.keys )
#         end
#
#         liveData.each do |k|
#           @log.debug( sprintf( ' => %s', self.findUid( historicData, k.values[1] ) ) )
#         end
#
#         @log.debug( sprintf( ' => %s', self.findUid( historicData, 'i-5f525fa9' ) ) )
#
# #         @mc.set( 'consumer__historic__data', liveData, 60*3 )
#       end

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

        @data = consumer.getData()
      }

      threads.each {|t| t.join }

      threads << Thread.new {

        @data = self.compareVersions()
      }

      threads.each {|t| t.join }

#      fork do
#
#        @data = consumer.getData()
#
#        @log.debug( @data )
#      end


#      fork do
#        self.compareVersions()
#      end
#
#      Process.waitall

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
