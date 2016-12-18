#!/usr/bin/ruby
#
# 17.12.2016 - Bodo Schulz
#
#
# v0.9.0

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'dalli'
require 'rest-client'

# -----------------------------------------------------------------------------

# Monkey patches

class Array
  def compare( comparate )
    to_set == comparate.to_set
  end
end

class Hash
  def filter( *args )
    if( args.size == 1 )
      if( args[0].is_a?( Symbol ) )
        args[0] = args[0].to_s
      end
      self.select { |key| key.to_s.match( args.first ) }
    else
      self.select { |key| args.include?( key ) }
    end
  end
end

# -----------------------------------------------------------------------------

module Logging

  def logger
    @logger ||= Logging.logger_for(self.class.name)
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def configure_logger_for(classname)

#      logFile         = '/var/log/monitoring/monitoring.log'
#      file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#      file.sync       = true
#      logger          = Logger.new( file, 'weekly', 1024000 )

      logger                 = Logger.new(STDOUT)
      logger.progname        = classname
      logger.level           = Logger::DEBUG
      logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      logger.formatter       = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime( logger.datetime_format )}] #{severity.ljust(5)} : #{progname} - #{msg}\n"
      end

      logger
    end
  end
end

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class DataConsumer

    include Logging

    attr_reader :data

    def initialize( settings )

      @memcacheHost = settings[:memcacheHost] ? settings[:memcacheHost] : nil
      @memcachePort = settings[:memcachePort] ? settings[:memcachePort] : nil

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'discover',
        :expires_in => 60*2
      }

#       @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      logger.debug( 'initialized' )
#       logger.debug( 'initialized' )

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
            logger.error( sprintf( ' [%s] ', responseCode ) )
            logger.error( sprintf( '  %s  ', response.body ) )
          end
        end
      rescue Exception => e
        logger.error( e )
        logger.error( e.backtrace )

        status  = 404
        message = sprintf( 'internal error: %s', e )
      end

    end


    def mockupData()

      # states:
#       0 : pending
#       16 : running
#       32 : shutting-down
#       48 : terminated
#       64 : stopping
#       80 : stopped

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
          "tags": {
            "customer": "moebius"
          }
        }
      ]


      return data

    end

  end


  class NetworkClient

    include Logging

    def initialize( settings )

      @apiHost    = settings[:host]    ? settings[:host]      : 'localhost'
      @apiPort    = settings[:port]    ? settings[:port]      : 80
      @apiVersion = settings[:version] ? settings[:version]   : 2
      @apiUrl     = settings[:url]     ? settings[:url]       : nil

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }

    end


    def fetch( path = '/' )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )

      begin
        data   = restClient.get( @headers ).body
        data   = JSON.parse( data )

        return data

      rescue Exception => e

        logger.error( e )
        return nil
      end

    end


    def remove( path )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )

      payload = {
        "grafana" => true,
        "icinga2" => true
      }

      begin
        data   = restClient.delete()
        data   = JSON.parse( data )

        return data

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        return nil
      end

    end


    def add( path, tags = {} )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )
#
# logger.debug( tags )

      begin
        data   = restClient.post( tags )
        data   = JSON.parse( data )

        logger.debug( data )

        return data

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )

        return nil
      end

    end

  end


  class Client

    include Logging

    def initialize( settings = {} )

      @apiHost            = settings[:apiHost]      ? settings[:apiHost]      : 'localhost'
      @apiPort            = settings[:apiPort]      ? settings[:apiPort]      : 80
      @apiVersion         = settings[:apiVersion]   ? settings[:apiVersion]   : 2
      @historic = []

      @apiUrl       = sprintf( 'http://%s/api/v%s', @apiHost, @apiVersion )

#       @memcacheHost = settings[:memcacheHost] ? settings[:memcacheHost] : nil
#       @memcachePort = settings[:memcachePort] ? settings[:memcachePort] : nil

      # add cache setting
      # eg.cache for 2 min here. default options is never expire
#       memcacheOptions = {
#         :compress   => true,
#         :namespace  => 'external-discover'
# #        :expires_in => 60*3
#       }

#       @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      version              = '0.1.1'
      date                 = '2016-12-15'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016 Coremedia' )
#       if( @supportMemcache == true )
#         logger.info( sprintf( '  Memcache Support enabled (%s:%s)', @memcacheHost, @memcachePort ) )
#       end
      logger.info( "  Backendsystem #{@apiUrl}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )
    end


    def compareVersions()

      logger.debug( 'compare' )

      liveData     = @data
      historicData = @historic # @mc.get( 'consumer__historic__data' ) || []

      identicalEntries      = liveData & historicData
      removedEntries        = liveData - historicData

      liveDataCount         = liveData.count
      historicDataCount     = historicData.count
      identicalEntriesCount = identicalEntries.count
      removedEntriesCount   = removedEntries.count

      logger.info( sprintf( 'live Data holds %d entries'    , liveDataCount ) )
#       logger.debug( "  #{liveData}" )
      logger.info( sprintf( 'historic Data holds %d entries', historicDataCount ) )
#       logger.debug( "  #{historicData}" )
      logger.info( sprintf( 'identical entries %d'          , identicalEntriesCount ) )
#       logger.debug(  "  #{identicalEntries}" )
      logger.info( sprintf( 'removed entries %d'            , removedEntriesCount ) )
#       logger.debug(  "  #{removedEntries}" )

      logger.debug( '------------------------------------------------------------' )


      def findUid( historic, uid )

        logger.debug( sprintf( 'findUid %s', uid ) )

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
        :host    => @apiHost,
        :port    => @apiPort,
        :version => @apiVersion,
        :url     => @apiUrl
      }

      net   = NetworkClient.new( options )

      # we have nothing .. first run
      if( historicDataCount.to_i == 0 )

        logger.info( 'no historic data found, first run' )

        newArray = Array.new()

        # add all founded nodes

        liveData.each do |l|

          ip      = l[:ip]      ? l[:ip]      : nil
          name    = l[:name]    ? l[:name]    : nil
          state   = l[:state]   ? l[:state]   : 'running'
          tags    = l[:tags]    ? l[:tags]    : []#
          useableTags = Array.new()

          logger.info( sprintf( 'get information about %s (%s)', name, ip ) )

          # get node data
          result = net.fetch( name )

          if( result != nil )
            dnsStatus  = result.dig( name, 'dns' )

            # check DNS resolving
            if( dnsStatus == false )
              logger.error( '  DNS Problem! try IP' )
              secondTest = net.fetch( ip )
              if( secondTest != nil )
                dnsStatus  = secondTest.dig( ip, 'dns' )
                if( dnsStatus == false || dnsStatus == nil )
                  logger.error( '  Host are not available. skip' )
                  next
                end
              end

            end

            discoveryStatus  = result.dig( name, 'discovery', 'status' )

            # {"status"=>400, "message"=>"Host are not available (DNS Problem)"}
            if( discoveryStatus == 400 )
              logger.info( '  The DNS of this host are not resolveable ... skip' )
              next

            # not exists
            elsif( discoveryStatus == 404 )

              logger.info( '  host not in monitoring ... try to add' )

              # our positive list for Tags
              useableTags = tags.filter( :customer, :environment, :tier )

#               logger.debug( useableTags )

              # add to monitoring
              d = JSON.generate( {
                :discovery  => true,
                :icinga     => false,
                :grafana    => true,
                :annotation => true,
                :tags       => useableTags
              } )

              result = net.add( name, d )

              logger.debug( result )

              if( result != nil )

              discoveryStatus  = result.dig( :status )
              discoveryMessage = result.dig( :message )

              if( discoveryStatus == 400 )
                # error
                logger.error( sprintf( '  => %s', discoveryMessage ) )
              elsif( discoveryStatus == 409 )
                # Host already created
                logger.error( sprintf( '  => %s', discoveryMessage ) )

                newArray << l
              else
                logger.info( 'Host successful added' )
                # successful
                newArray << l
              end

              end

            end

          end
        end

        logger.debug( newArray )

        @historic = newArray
#         @mc.set( 'consumer__historic__data', newArray )
      end


      # remove hosts
      if( historicDataCount.to_i != 0 && removedEntriesCount.to_i != 0 )

        # remove hosts from monitoring

        removedEntries.each do |r|

          ip      = r[:ip]      ? r[:ip]      : nil
          name    = r[:name]    ? r[:name]    : nil

          if( ip != nil && name != nil )

            logger.info( sprintf( 'remove host %s (%s) from monitoring', name, ip ) )

            result = net.remove( name )

            if( result == nil )
              next
            end

            discoveryStatus  = result.dig( name, 'discovery', 'status' )
            discoveryMessage = result.dig( name, 'discovery', 'message' )

            logger.info( sprintf( '  %s - %s', discoveryStatus, discoveryMessage ) )

          end
        end

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
#        logger.debug( @data )
#      end


#      fork do
#        self.compareVersions()
#      end
#
#      Process.waitall

      logger.debug( 'done' )

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
