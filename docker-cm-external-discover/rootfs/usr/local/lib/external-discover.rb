#!/usr/bin/ruby
#
# 17.12.2016 - Bodo Schulz
#
#
# v0.9.1

# -----------------------------------------------------------------------------

require 'json'
require 'rest-client'

require_relative 'monkey'
require_relative 'logging'
require_relative 'cache'
require_relative 'utils/network'

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class DataConsumer

    include Logging

    attr_reader :data

    def initialize( settings )

      discoveryHost      = settings.dig(:discoveryHost)
      discoveryPort      = settings.dig(:discoveryPort)
      discoveryPath      = settings.dig(:discoveryPath)

      @discoveryUrl      = sprintf( 'http://%s:%d%s', discoveryHost, discoveryPort, discoveryPath )

      logger.debug( 'initialized' )

      @total = 0
      @mutex = Mutex.new
    end


    def getData()

      @data = @mutex.synchronize { self.client() }

      logger.debug( @data )

      return @data

    end


    def client()

      # `curl http://monitoring.develop.cosmos.internal:8080/api/aws

      uri = URI( @discoveryUrl )

      response = nil

      begin

        Net::HTTP.start( uri.host, uri.port ) do |http|

          request = Net::HTTP::Get.new( uri.request_uri )

          request.add_field('Content-Type', 'application/json')

          response     = http.request( request )
          responseCode = response.code.to_i

          if( responseCode == 200 )

            responseBody  = JSON.parse( response.body )

            return( responseBody )

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

            return {
              :status  => responseCode,
              :message => response.body
            }
          end
        end
      rescue Exception => e
#         logger.error( e )
#         logger.error( e.backtrace )

        message = sprintf( 'internal error: %s', e )

        return {
          :status  => 404,
          :message => message
        }
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

        response     = restClient.get( @headers )

        responseCode = response.code
        responseBody = response.body

logger.debug( response.class.to_s )
logger.debug( response.inspect )
logger.debug( response )

logger.debug( responseCode )
logger.debug( responseBody )

        if( responseCode == 200 )

          data   = JSON.parse( responseBody )

          return data

        elsif( responseCode == 204 )

          return { 'status' => responseCode }

        end

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
        "force" => true
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

      apiHost        = settings[:apiHost]       ? settings[:apiHost]       : nil
      apiPort        = settings[:apiPort]       ? settings[:apiPort]       : nil
      apiVersion     = settings[:apiVersion]    ? settings[:apiVersion]    : 2

      @discoveryHost = settings[:discoveryHost] ? settings[:discoveryHost] : nil
      @discoveryPort = settings[:discoveryPort] ? settings[:discoveryPort] : nil
      @discoveryPath = settings[:discoveryPath] ? settings[:discoveryPath] : nil

      @apiUrl        = sprintf( 'http://%s/api/v%s', apiHost, apiVersion )
      @discoveryUrl  = sprintf( 'http://%s:%d%s', @discoveryHost, @discoveryPort, @discoveryPath )
      @historic      = []

      version        = '0.9.1'
      date           = '2017-01-05'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016 Coremedia' )
      logger.info( "  Monitoring System #{@apiUrl}" )
      logger.info( "  Discovery System #{@discoveryUrl}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )
    end



    def nsLookup( name )

          # DNS
          #
          hostname = sprintf( 'dns-%s', name )

          dns      = @cache.get( hostname )

          logger.debug( dns )

          if( dns == nil )

            # create DNS Information
            dns      = Utils::Network.resolv( ip )

            ip    = dns.dig(:ip)
            short = dns.dig(:short)
            fqdn  = dns.dig(:long)

            @cache.set( hostname , expiresIn: 120 ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }

          else

            ip    = dns.dig(:ip)
            short = dns.dig(:short)
            fqdn  = dns.dig(:long)

          end
          #
          # ------------------------------------------------

      return ip, short, fqdn

    end


    def compareVersions()

      logger.debug( 'compare' )

      liveData     = @data
      historicData = @historic

      logger.debug( liveData )
      logger.debug( liveData.class.to_s )
      logger.debug( historicData )
      logger.debug( historicData.class.to_s )

      if( liveData.is_a?( Array ) == false )
        logger.error( 'liveData is not an Array' )

        return
      end

      if( historicData.is_a?( Array ) == false )
        logger.error( 'historicData is not an Array' )

        return
      end

      identicalEntries      = liveData & historicData
      removedEntries        = liveData - historicData

      liveDataCount         = liveData.count
      historicDataCount     = historicData.count
      identicalEntriesCount = identicalEntries.count
      removedEntriesCount   = removedEntries.count

      logger.info( sprintf( 'live Data holds %d entries'    , liveDataCount ) )
      logger.debug( "  #{liveData}" )
      logger.info( sprintf( 'historic Data holds %d entries', historicDataCount ) )
      logger.debug( "  #{historicData}" )
      logger.info( sprintf( 'identical entries %d'          , identicalEntriesCount ) )
      logger.debug(  "  #{identicalEntries}" )
      logger.info( sprintf( 'removed entries %d'            , removedEntriesCount ) )
      logger.debug(  "  #{removedEntries}" )

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

          ip          = l.dig('ip')
          displayName = l.dig('name')
          state       = l.dig('state') || 'running'
          tags        = l.dig('tags')  || []

          if( displayName == nil )
            logger.warn( 'no cname configured, skip' )
            next
          end

          # states from AWS:
          #  0 : pending
          # 16 : running
          # 32 : shutting-down
          # 48 : terminated
          # 64 : stopping
          # 80 : stopped

          useableTags = Array.new()

          logger.info( sprintf( 'get information about %s (%s)', ip, name ) )

          # get node data
          result = net.fetch( ip )

          logger.debug( result )

          if( result != nil )

            status = result.dig('status') || 400

            if( status.to_i == 200 )
              logger.info( 'node are in monitoring available' )
              next
            end

            if( status.to_i == 204 )

              discoveryStatus == status

              ip, short, fqdn = self.nsLookup( ip )

              if( ip != nil )
                name = ip
              else
                discoveryStatus = 400
              end
            end

#             discoveryStatus = 204
#
#             dnsStatus  = result.dig( ip, 'dns' )
#
#             # check DNS resolving
#             if( dnsStatus == false || dnsStatus == nil )
#
#               logger.debug( '  DNS Problem! try own ns lookup' )
#
#               ip, short, fqdn = self.nsLookup(ip )
#
#               secondTest = net.fetch( ip )
#
#               if( secondTest != nil )
#
#                 dnsStatus  = secondTest.dig( ip, 'dns' )
#
#                 if( dnsStatus == false || dnsStatus == nil )
#                   logger.error( '  Host are not available. skip' )
#                   next
#                 else
#                   result = secondTest
#                   name   = ip
#                 end
#               end
#             else
#               name  = ip
#             end
#
#             discoveryStatus  = result.dig( name, 'discovery', 'status' )
#
#             logger.debug( discoveryStatus )
#             logger.debug( discoveryStatus.class.to_s )

            # {"status"=>400, "message"=>"Host are not available (DNS Problem)"}
            if( discoveryStatus == 400 )
              logger.info( '  The DNS of this host are not resolveable ... skip' )
              next

            # not exists
            elsif( discoveryStatus == nil || discoveryStatus == 204 || discoveryStatus == 404 )

              logger.info( '  host not in monitoring ... try to add' )

              logger.debug( "tags: #{tags}" )

              # our positive list for Tags
              useableTags = tags.filter( 'customer', 'environment', 'tier' )

              logger.debug( "useableTags: #{useableTags}" )

              # add to monitoring
              # defaults:
              # - discovery  = true
              # - icinga     = true
              # - grafana    = true
              # - annotation = true
              d = JSON.generate( {
                :tags       => useableTags,
                :config     => { 'display-name' => displayName }
              } )

              logger.debug( "data: #{d}" )

              result = net.add( name, d )

              logger.debug( result )

              if( result != nil )

                discoveryStatus  = result.dig( "status" )
                discoveryMessage = result.dig( "message" )

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

                sleep(2)

              end

            end

          end
        end

        logger.debug( newArray )

        @historic = newArray
      end


      # remove hosts
      if( historicDataCount.to_i != 0 && removedEntriesCount.to_i != 0 )

        # remove hosts from monitoring

        removedEntries.each do |r|

          ip      = r["ip"]      ? r["ip"]      : nil
          name    = r["name"]    ? r["name"]    : nil

          if( ip != nil && name != nil )

            logger.info( sprintf( 'remove host %s (%s) from monitoring', ip, name ) )

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
        :discoveryHost => @discoveryHost,
        :discoveryPort => @discoveryPort,
        :discoveryPath => @discoveryPath
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
