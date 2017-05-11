#!/usr/bin/ruby
#
# 17.12.2016 - Bodo Schulz
#
#
# v0.9.1

# -----------------------------------------------------------------------------

require 'aws-sdk'
require 'json'
require 'rest-client'

require_relative 'logging'
require_relative 'monkey'
require_relative 'aws/client'
require_relative 'cache'
require_relative 'utils/network'

# -----------------------------------------------------------------------------

module ExternalDiscovery


  class DataConsumer

    include Logging

    attr_reader :data

    def initialize( settings )

      @filter  = settings.dig(:filter)

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service - AWS Data Consumer' )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @awsClient = Aws::Ec2::Client.new()

    end


    def client()

      response = nil

      begin

        @data = @awsClient.instances( { :filter => @filter } )

      rescue => e
        logger.error( e )
        logger.error( e.backtrace )

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

      @apiHost    = settings.dig(:monitoring, :host)    || 'localhost'
      @apiPort    = settings.dig(:monitoring, :port)    || 80
      @apiVersion = settings.dig(:monitoring, :version) || 2
      @apiUrl     = settings.dig(:monitoring, :url)

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service - Monitoring NetworkClient' )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

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

# logger.debug( response.class.to_s )
# logger.debug( response.inspect )
# logger.debug( response )
#
# logger.debug( responseCode )
# logger.debug( responseBody )

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

      logger.debug( "add( #{path}, #{tags} )" )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url ),
        :timeout      => 5,
        :open_timeout => 5,
      )
#
# logger.debug( tags )

      begin
        data   = restClient.post( tags )
        data   = JSON.parse( data )

        logger.debug( data )

        return data

      rescue RestClient::Exceptions::ReadTimeout => e

        logger.error( e.inspect )
#         logger.error( e.code )
#         logger.error( e.body )


        logger.error( e.message )

        return {
          :status  => 408,
          :message => e.message
        }

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        logger.error( e.message )

        return {
          :status  => 500,
          :message => e.message
        }

      rescue => e

        logger.error( e.inspect )

        return nil
      end

    end

  end


  class Client

    include Logging

    def initialize( settings = {} )

      # Monitoring
      #
      apiHost        = settings.dig(:monitoring, :host)    || 'localhost'
      apiPort        = settings.dig(:monitoring, :port)    || 80
      apiVersion     = settings.dig(:monitoring, :version) || 2
      apiUrl         = sprintf( 'http://%s/api/v%s', apiHost, apiVersion )

      # AWS
      #
      awsRegion      = settings.dig(:aws, :region)

      @historic      = []

      version        = '0.10.2'
      date           = '2017-05-11'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( "  Monitoring System #{apiUrl}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      if( awsRegion == nil )
        logger.error( 'aws region are nil' )
        raise 'aws region are nil'
      end

      config = {
        :monitoring => {
          :host    => apiHost,
          :port    => apiPort,
          :version => apiVersion,
          :url     => apiUrl
        }
      }

      filter = [
        { name: 'instance-state-name', values: ['running'] },
        { name: 'tag-key'            , values: ['monitoring-enabled'] }
      ]

      @dataConsumer  = DataConsumer.new( { :filter => filter } )
      @networkClient = NetworkClient.new( config )
      @cache         = Cache::Store.new()


    end



    def nsLookup( name, expire = 120 )

      # DNS
      #
      hostname = sprintf( 'dns-%s', name )

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( hostname )

      if( dns == nil )

        logger.debug( 'create cached DNS data' )
        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @cache.set( hostname , expiresIn: expire ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
        else
          logger.error( 'no DNS data found!' )
          logger.error( " => #{dns}" )
        end
      else

        logger.debug( 're-use cached DNS data' )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

      end
      #
      # ------------------------------------------------

      logger.debug( sprintf( ' ip   %s ', ip ) )
      logger.debug( sprintf( ' host %s ', short ) )
      logger.debug( sprintf( ' fqdn %s ', fqdn ) )

      return ip, short, fqdn

    end




    def normalizeName( name, filter = [] )

      filter.each do |f|

        name.gsub!( f, '' )
      end

#      name.gsub!('-','')
      name.gsub!('development-','dev ')
      name.gsub!('production-' ,'prod ')
      name.gsub!('caepreview' , 'cae preview')

#       name = case name
#         when 'cms'
#           'content-management-server'
#         when 'mls'
#           'master-live-server'
#         when 'rls'
#           'replication-live-server'
#         when 'wfs'
#           'workflow-server'
#         when 'delivery'
#           'cae-live-1'
#         when 'solr'
#           'solr-master'
#         when 'contentfeeder'
#           'content-feeder'
#         when 'workflow'
#           'workflow-server'
#         else
#           name
#       end

      return name

    end



    def compareVersions( params = {} )

      logger.debug( 'compare' )

      liveData     = params.dig( 'live' )
      historicData = @historic

#       logger.debug( liveData )
#       logger.debug( liveData.class.to_s )
#       logger.debug( historicData )
#       logger.debug( historicData.class.to_s )

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

      # we have nothing .. first run
      if( historicDataCount.to_i == 0 )

        logger.info( 'no historic data found, first run' )

        discoveryStatus = 204
        newArray        = Array.new()

        # add all founded nodes

        liveData.each do |l|

#          fqdn        = l.dig('fqdn')
#          name        = l.dig('name')
          state       = l.dig('state') || 'running'
#          dns         = l.dig('dns')
          tags        = l.dig('tags')  || []
          cname       = l.dig('tags', 'cname')
          name        = l.dig('tags', 'name')
          tier        = l.dig('tags', 'tier')
          customer    = l.dig('tags', 'customer')
          environment = l.dig('tags', 'environment')
          ip          = l.dig('dns' , 'ip')
          fqdn        = l.dig('dns' , 'name')


          # currently, we want only the dev environment
          #
          if( environment != 'development' )
            next
          end

          if( cname == nil || cname == '.' )
            logger.warn( "cname for '#{name}' are not configured, skip" )
            next
          end

          if( tier == nil || tier == 'service' )
            logger.warn( "tier for '#{name}' are not configured, skip" )
            next
          end

          environment = case environment
            when 'development'
              'dev'
            when 'production'
              'prod'
            else
              environment
            end

          # -----------------------------------------------------------------------------

          if( ! cname.include?( 'cms' ) )
            next
          end

          displayName = normalizeName( name, [ 'cosmos-', 'delivery-', 'management-', 'storage-' ] )

          logger.debug( "environment: #{environment}" )
          logger.debug(" -> #{cname} - #{name}" )
          logger.debug( "  ==> #{displayName}" )


          # states from AWS:
          #  0 : pending
          # 16 : running
          # 32 : shutting-down
          # 48 : terminated
          # 64 : stopping
          # 80 : stopped

          useableTags = Array.new()

          logger.info( sprintf( 'get information about %s (%s)', fqdn, cname ) )

          ip, short, fqdn = self.nsLookup( fqdn )

          # get node data
          result = @networkClient.fetch( short )

#           logger.debug( result )

          if( result != nil )

            status = result.dig('status') || 400

            if( status.to_i == 200 )
              logger.info( 'node are in monitoring available' )
              next
            end

#             if( status.to_i == 204 )
#
#               logger.info( 'node not in monitoring found, get dns information' )
#
#               discoveryStatus = status
#
#               ip, short, fqdn = self.nsLookup( ip )
#
# #               logger.debug( ip )
#
#               if( ip != nil )
#                 name = ip
#               else
#                 discoveryStatus = 400
#               end
#             end


#             logger.debug( discoveryStatus )


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
            #if( discoveryStatus == 400 )
            #  logger.info( '  The DNS of this host are not resolveable ... skip' )
            #  next
            #
            ## not exists
            #els
            if( discoveryStatus == nil || discoveryStatus == 204 || discoveryStatus == 404 )

              logger.info( '  now, we try to add them' )

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

              result = @networkClient.add( short, d )

              logger.debug( result )

              logger.debug( '------------------------' )


              if( result != nil )

                discoveryStatus  = result.dig( :status )   || result.dig( 'status' )
                discoveryMessage = result.dig( :message )  || result.dig( 'message' )

                if( discoveryStatus == 400 )
                  # error
                  logger.error( sprintf( '  => %s', discoveryMessage ) )
                elsif( discoveryStatus == 409 )
                  # Host already created
                  logger.error( sprintf( '  => %s', discoveryMessage ) )

                  newArray << l
                elsif( discoveryStatus == 408 )
                  # error
                  logger.error( sprintf( '  => %s', discoveryMessage ) )
                elsif( discoveryStatus == 500 )
                  # error
                  logger.error( sprintf( '  => %s', discoveryMessage ) )
                else
                  logger.info( 'Host successful added' )
                  # successful
                  newArray << l
                end

                sleep(4)

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

          ip      = r.dig('ip')
          name    = r.dig('name')

          if( ip != nil && name != nil )

            logger.info( sprintf( 'remove host %s (%s) from monitoring', fqdn, cname ) )

            result = @networkClient.remove( name )

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

      logger.info( 'get AWS  data' )

      start = Time.now

      awsData  = @cache.get( 'aws-data' )

      if( awsData == nil )

        logger.debug( 'get data from AWS' )

        awsData = @dataConsumer.client()

        @cache.set( 'aws-data' , expiresIn: 120 ) { Cache::Data.new( awsData ) }

      else

        logger.debug( 'found cached AWS data' )

      end

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )


      logger.debug( JSON.pretty_generate( awsData ) )




#       logger.debug( JSON.pretty_generate( data ) )

#       self.compareVersions( { 'live' => data } )




      logger.debug( 'done' )

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
