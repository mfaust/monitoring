
require 'json'

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class Client

    include Logging

    include ExternalDiscovery::Tools

    def initialize( settings = {} )

      # Monitoring
      #
      apiHost        = settings.dig(:monitoring, :host)    || 'localhost'
      apiPort        = settings.dig(:monitoring, :port)    || 80
      apiVersion     = settings.dig(:monitoring, :version) || 2
      apiUrl         = sprintf( 'http://%s/api/v%s', apiHost, apiVersion )

      # AWS
      #
      @awsRegion      = settings.dig(:aws, :region)
      @awsEnvironment = settings.dig(:aws, :environment)

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

      if( @awsRegion == nil )
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
        { name: 'tag-key'            , values: ['monitoring-enabled'] },
        { name: 'tag:monitoring-enabled', values: ['true'] },
        { name: 'tag:environment'    , values: [@awsEnvironment] }
      ]

      @jobs             = JobQueue::Job.new()
      @cache            = Cache::Store.new()
      @dataConsumer     = DataConsumer.new( { :filter => filter } )
      @monitoringClient = MonitoringClient.new( config )

    end


    def compareVersions( params = {} )

#       logger.debug( "compareVersions( #{params} )" )

      aws_data        = params.dig( 'aws' )
      monitoring_data = params.dig( 'monitoring' )

      if( aws_data.is_a?( Array ) == false )
        logger.error( 'aws_data is not an Array' )

        return
      end

      if( monitoring_data.nil? )
        monitoring_data = Array.new
      end

      if( monitoring_data.is_a?( Hash ) )
        monitoring_data = Array[*monitoring_data]
      end

      if( monitoring_data.is_a?( Array ) == false )
        logger.error( 'monitoring_data is not an Array' )

        return
      end

      unknownHost = Array.new()

      ## get all dns_fqdn entries
      #
      aws = getFqdn( aws_data )

#       logger.debug( "AWS: #{aws_data}" )

      identicalEntries      = aws & monitoring_data
      removedEntries        = monitoring_data - aws
      newEntries            = aws - identicalEntries


      aws_dataCount         = aws_data.count
      monitoring_dataCount  = monitoring_data.count
      identicalEntriesCount = identicalEntries.count
      removedEntriesCount   = removedEntries.count
      newEntriesCount       = newEntries.count

      logger.debug( '------------------------------------------------------------' )
      logger.info( sprintf( 'AWS holds %d entries', aws_dataCount ) )
      logger.info( sprintf( 'MON holds %d entries', monitoring_dataCount ) )
      logger.debug( '------------------------------------------------------------' )
      logger.info( sprintf( 'identical entries %d', identicalEntriesCount ) )
      logger.debug(  "  #{identicalEntries}" )
      logger.info( sprintf( 'new entries %d', newEntriesCount ) )
      logger.debug(  "  #{newEntries}" )
      logger.info( sprintf( 'removed entries %d', removedEntriesCount ) )
      logger.debug(  "  #{removedEntries}" )
      logger.debug( '------------------------------------------------------------' )

      removedEntries.each do |r|

        logger.info( sprintf( '  remove node %s', r ) )

        result = self.nodeDelete( { :ip => r } )

        logger.debug( result )
      end


      # TODO
      # we need an better way to detect adding or removing!
      # or re-adding, when the node comes up with an new ip

      newEntries.each do |a|

        d           = entry_with_fqdn( aws_data, a )

        aws_state       = d.dig('state') || 'running'
        aws_uuid        = d.dig('uid')
        aws_region      = d.dig('region')
        aws_tags        = d.dig('tags')  || []
        tag_name        = d.dig('tags', 'name')
        tag_tier        = d.dig('tags', 'tier')
        tag_customer    = d.dig('tags', 'customer')
        tag_environment = d.dig('tags', 'environment')
        tag_cm_apps     = d.dig('tags', 'cm_apps')
        dns_ip          = d.dig('dns', 'ip')
        dns_short       = d.dig('dns', 'short')
        dns_fqdn        = d.dig('dns', 'fqdn')

        if( !['cosmos-development-management-cms','cosmos-development-delivery-mls','cosmos-development-delivery-rls-cae'].include?(tag_name) )
          logger.debug( "skip: '#{tag_name}'" )
          next
        end

#        logger.debug( "#{tag_name}: #{dns_ip} - #{dns_short} - #{dns_fqdn}" )
        logger.info( sprintf( '  add node %s / %s (%s)', aws_uuid, dns_fqdn, tag_name ) )

        display_name = graphite_identifier = graphiteIdentifier( { :name => tag_name } )
        environment =
            case environment
            when 'development'
              'dev'
            when 'production'
              'prod'
            else
              environment
            end

        params = {
          :ip          => dns_ip,
          :short       => dns_short,
          :fqdn        => dns_fqdn,
          :uuid        => aws_uuid,
          :region      => aws_region,
          :tags        => aws_tags,
          :name        => tag_name,
          :customer    => tag_customer,
          :environment => environment,
          :tier        => tag_tier,
          :display_name => display_name,
          :graphite_identifier => graphite_identifier
        }

        logger.debug( "display name: #{display_name}" )
        logger.debug( "graphite identifier: #{graphite_identifier}" )
        logger.debug("params: #{params}")

        result = self.nodeAdd(params)

        if( result == true )
          sleep(8)
        end

        sleep(2)

      end


#       aws_data.each do |l|
#
#         data = l.clone
#
#         uuid, dns_ip, dns_short, dns_fqdn, fqdn, name, state, tags, cname, name, tier, customer, environment = self.extractInstanceInformation( data )
#
#         # PRIMARY FILTER
#         # currently, we want only the following services:
#         #  - cosmos-development-management-cms
#         #  - cosmos-production-delivery-mls
#         #  - cosmos-development-delivery-rls-cae
#         #
#         if( !['cosmos-development-management-cms','cosmos-development-delivery-mls','cosmos-development-delivery-rls-cae'].include?(name) )
#           logger.debug( "skip: '#{name}'" )
#           next
#         end
#
# #         if( cname == nil || cname == '.' )
# #           logger.warn( "  cname not configured - '#{name}' will be ignored ..." )
# #           next
# #         end
#
#         if( tier == nil || tier == 'service' || tier == 'storage' )
#           logger.warn( "  wrong tier #{tier} - '#{name}' will be ignored ..." )
#           next
#         end
#
#         ip, short, fqdn = nsLookup( fqdn )
#
#         if( ip == nil || short == nil || fqdn == nil )
#           logger.error( 'DNS problem, skip' )
#           next
#         end
#
#         logger.debug( monitoring_data )
#         logger.debug( "#{name}: #{ip} - #{short} - #{fqdn} | #{dns_ip} - #{dns_short} - #{dns_fqdn}" )
#
#         if( monitoring_data.include?( dns_fqdn ) || monitoring_data.include?( fqdn ) )
#           logger.info( sprintf( '  node %s / %s (%s) exists', uuid, dns_fqdn, name ) )
#           next
#         else
#
#           unknownHost << {
#             :ip          => ip,
#             :short       => short,
#             :fqdn        => fqdn,
#             :uuid        => uuid,
#             :cname       => cname,
#             :name        => name,
#             :customer    => customer,
#             :environment => environment,
#             :tier        => tier,
#             :tags        => tags
#           }
#
#         end
#
#         logger.info( sprintf( '  add node %s / %s (%s)', uuid, dns_fqdn, cname ) )
#
#         result = self.nodeAdd({
#           :ip          => ip,
#           :short       => short,
#           :fqdn        => fqdn,
#           :uuid        => uuid,
#           :cname       => cname,
#           :name        => name,
#           :customer    => customer,
#           :environment => environment,
#           :tier        => tier,
#           :tags        => tags
#         })
#
#         if( result == true )
#
#           sleep(8)
#         end
#
#         sleep(2)
#
#       end
#
#       aws_data = nil

      sleep(20)

      return

    end


    def nodeAdd( params = {} )

      ip          = params.dig(:ip)
      short       = params.dig(:short)
      fqdn        = params.dig(:fqdn)
      uuid        = params.dig(:uuid)
      region      = params.dig(:region)
      tags        = params.dig(:tags)
      name        = params.dig(:name)
      customer    = params.dig(:customer)
      environment = params.dig(:environment)
      tier        = params.dig(:tier)
      display_name = params.dig(:display_name)
      graphite_identifier = params.dig(:graphite_identifier)

      discoveryStatus = 204
      useableTags     = Array.new()

      logger.debug( "original tags: #{tags}" )

      # our positive list for Tags
      #
      useableTags = tags.filter( 'customer', 'environment', 'tier' )

      logger.debug( "useable tags : #{useableTags}" )

      # add to monitoring
      # defaults:
      # - discovery  = true
      # - icinga     = true
      # - grafana    = true
      # - annotation = true
      d = {
        :force      => false,
        :tags       => useableTags,
        :config     => {
          :display_name        => display_name,
          :graphite_identifier => graphite_identifier,
          :tags                => useableTags,
          :customer            => customer,
          :environment         => environment,
          :tier                => tier,
          :aws                 => {
            :region  => region,
            :uuid    => uuid,
            :name    => name
          },
          :services            => tags.dig('services')
        }
      }

#       logger.debug( JSON.pretty_generate( d ) )

      result = @monitoringClient.add( ip, JSON.generate(d) )

      logger.debug( result )

      if( result.is_a?(Hash) )

        discoveryStatus  = result.dig( :status )   || result.dig( 'status' )
        discoveryMessage = result.dig( :message )  || result.dig( 'message' )

        if( discoveryStatus == 400 )
          # error
          logger.error( sprintf( '  => %s', discoveryMessage ) )

          return false
        elsif( discoveryStatus == 409 )
          # Host already created
          logger.error( sprintf( '  => %s', discoveryMessage ) )

          return true
        elsif( discoveryStatus == 408 )
          # request timeout
          logger.error( sprintf( '  => %s', discoveryMessage ) )

          return false
        elsif( discoveryStatus == 500 )
          # internal error
          logger.error( sprintf( '  => %s', discoveryMessage ) )

          return false
        else
          logger.info( 'Host successful added' )
          # successful
          return true
        end

      end

      return false

    end


    def nodeDelete( params = {} )

      ip          = params.dig(:ip)

      ip, short, fqdn = nsLookup( ip )

      logger.info( sprintf( 'remove host %s (%s) from monitoring', fqdn, ip ) )

      result = @monitoringClient.remove( ip )

      if( result == nil )
        logger.error( 'what going on?' )
        return false
      end

      discoveryStatus  = result.dig( name, 'discovery', 'status' )
      discoveryMessage = result.dig( name, 'discovery', 'message' )

      logger.info( sprintf( '  %s - %s', discoveryStatus, discoveryMessage ) )

      return true
    end

    # return 'true', when node currently in monitoring
    #
    def nodeStatus( params = {} )

      ip     = params.dig(:ip)
      short  = params.dig(:short)
      fqdn   = params.dig(:fqdn)

      result = @monitoringClient.fetch( short )

      logger.debug( result )

      if( result != nil )

        discoveryStatus = result.dig('status') || 400

        logger.debug( "status: #{discoveryStatus}" )

        if( discoveryStatus.to_i == 200 )

          logger.info( '  is already in monitoring' )



          return true
        end

      end

      return false

    end


    def run()

      # add a blocking cache
      #
      if( @jobs.jobs( { :status => 'running' } ) == true )

        logger.warn( 'we are working on this job' )
        return
      end

      @jobs.add( { :status => 'running' } )

      @data   = Array.new()
      threads = Array.new()

#      awsData        = @cache.get( 'aws-data' )
      awsData        = @dataConsumer.instances()

      monitoringData = @monitoringClient.monitoringData

#       if( awsData == nil )
#
#         awsData = @dataConsumer.instances()
#
#         if( awsData.is_a?(Array) && awsData.count() != 0 )
#           logger.debug( 'store data into cache' )
#           @cache.set( 'aws-data' , expiresIn: 120 ) { Cache::Data.new( awsData ) }
#         end
#
#         @jobs.del( { :status => 'running' } )
#         return
#
#       else
#
#         logger.debug( 'found cached AWS data' )
#       end

      start = Time.now

      logger.debug( sprintf( 'AWS hold %d nodes'       , awsData.count ) )
      logger.debug( sprintf( 'Monitoring hold %d nodes (%s)', monitoringData.count, monitoringData.to_s ) )

      logger.debug( 'look to insert new nodes, or delete removed ...' )

      self.compareVersions( { 'aws' => awsData, 'monitoring' => monitoringData } )

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

      @jobs.del( { :status => 'running' } )

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
