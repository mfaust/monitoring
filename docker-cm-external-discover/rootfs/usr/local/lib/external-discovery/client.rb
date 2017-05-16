
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

      @jobs             = JobQueue::Job.new()
      @cache            = Cache::Store.new()
      @dataConsumer     = DataConsumer.new( { :filter => filter } )
      @monitoringClient = MonitoringClient.new( config )

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


    def graphiteIdentifier( params = {} )

      customer  = params.dig(:customer)
      name      = params.dig(:name)
      ip        = params.dig(:ip)

      lastOktet = ip.split('.').last

      return sprintf( '%s-%s-%s', customer, name.gsub(' ', '-'), lastOktet )
    end


    def extractInstanceInformation( data = {} )

#      logger.debug( "extractInstanceInformation( #{data} )" )

#      fqdn        = data.dig('fqdn')
#      name        = data.dig('name')
      uuid        = data.dig('uid')
      state       = data.dig('state') || 'running'
#      dns         = data.dig('dns')
      tags        = data.dig('tags')  || []
      cname       = data.dig('tags', 'cname')
      name        = data.dig('tags', 'name')
      tier        = data.dig('tags', 'tier')
      customer    = data.dig('tags', 'customer')
      environment = data.dig('tags', 'environment')
      ip          = data.dig('dns' , 'ip')
      fqdn        = data.dig('dns' , 'name')

      return uuid, ip, fqdn, state, tags, cname, name, tier, customer, environment

    end


    def compareVersions( params = {} )

      liveData     = params.dig( 'live' )
      historicData = @cache.get( 'historic' )

      if( liveData.is_a?( Array ) == false )
        logger.error( 'liveData is not an Array' )

        return
      end

      if( historicData == nil )
        historicData = Array.new
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

      logger.debug( '------------------------------------------------------------' )
      logger.info( sprintf( 'live Data holds %d entries'    , liveDataCount ) )
#       logger.debug( "  #{liveData}" )
      logger.info( sprintf( 'historic Data holds %d entries', historicDataCount ) )
#       logger.debug( "  #{historicData}" )
      logger.debug( '------------------------------------------------------------' )
      logger.info( sprintf( 'identical entries %d'          , identicalEntriesCount ) )
#       logger.debug(  "  #{identicalEntries}" )
      logger.info( sprintf( 'removed entries %d'            , removedEntriesCount ) )
#       logger.debug(  "  #{removedEntries}" )
      logger.debug( '------------------------------------------------------------' )

      # TODO
      # we need an better way to detect adding or removing!
      # or re-adding, when the node comes up with an new ip

      logger.debug( @monitoringClient.monitoringData )



      return


      # we have nothing .. first run
      #
      if( historicDataCount.to_i == 0 )

        logger.info( 'no historic data found, first run' )

        newArray        = Array.new()

        # add all founded nodes

        liveData.each do |l|

          uuid, ip, fqdn, state, tags, cname, name, tier, customer, environment = self.extractInstanceInformation( l )

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

          ip, short, fqdn = nsLookup( fqdn )

          # -----------------------------------------------------------------------------

          # currently, we want only the CMS
          #
#           if( ! cname.include?( 'cms' ) )
#             next
#           end

          logger.info( sprintf( 'get information about %s (%s)', fqdn, cname ) )

          nodeStatus = self.nodeStatus( { :short => short } )

          if( nodeStatus == true )
            newArray << l

            next
          end

          if( self.nodeAdd( { :ip => ip, :short => short, :fqdn => fqdn, :cname => cname, :name => name, :customer => customer, :environment => environment, :tier => tier, :tags => tags } ) == true )

            newArray << l

            sleep(5)
          end

          sleep(2)

        end

        logger.debug( newArray )

        @cache.set( 'historic', expiresIn: 320 ) { Cache::Data.new( newArray ) }

      end


      # remove hosts
      #
#       if( historicDataCount.to_i != 0 && removedEntriesCount.to_i != 0 )
#
#         # remove hosts from monitoring
#         #
#         removedEntries.each do |r|
#
#           uuid, ip, fqdn, state, tags, cname, name, tier, customer, environment = self.extractInstanceInformation( r )
#
#           if( ip != nil && fqdn != nil )
#
#             self.nodeDelete( { :ip => ip, :fqdn => fqdn, :cname => cname } )
#           end
#         end
#
#       end


    end


    def nodeAdd( params = {} )

      ip          = params.dig(:ip)
      short       = params.dig(:short)
      fqdn        = params.dig(:fqdn)
      cname       = params.dig(:cname)
      name        = params.dig(:name)
      tags        = params.dig(:tags)
      customer    = params.dig(:customer)
      environment = params.dig(:environment)
      tier        = params.dig(:tier)

      environment = case environment
        when 'development'
          'dev'
        when 'production'
          'prod'
        else
          environment
        end

      displayName = normalizeName( name, [ 'cosmos-', 'delivery-', 'management-', 'storage-' ] )

#       logger.debug( "environment: #{environment}" )
#       logger.debug(" -> #{cname} - #{name}" )
#       logger.debug( "  ==> #{displayName}" )

      discoveryStatus = 204
      useableTags     = Array.new()

      logger.info( '  now, we try to add them' )

#       logger.debug( "original tags: #{tags}" )

      # our positive list for Tags
      useableTags = tags.filter( 'customer', 'environment', 'tier' )

#       logger.debug( "useable tags : #{useableTags}" )

      # add to monitoring
      # defaults:
      # - discovery  = true
      # - icinga     = true
      # - grafana    = true
      # - annotation = true
      d = JSON.generate( {
        :force      => false,
        :tags       => useableTags,
        :config     => {
          'display-name'        => displayName,
          'graphite-identifier' => self.graphiteIdentifier( { :customer => customer, :name => displayName, :ip => ip } )
        }
      } )

      logger.debug( "data: #{d}" )

      result = @monitoringClient.add( short, d )

      logger.debug( result )

      if( result != nil )

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
      fqdn        = params.dig(:fqdn)
      cname       = params.dig(:cname)

      logger.info( sprintf( 'remove host %s (%s) from monitoring', fqdn, cname ) )

      ip, short, fqdn = nsLookup( fqdn )

      result = @monitoringClient.remove( short )

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
      if( @jobs.jobs( { :fqdn => 'foo' } ) == true )

        logger.warn( 'we are working on this job' )
        return
      end

      @jobs.add( { :fqdn => 'foo' } )

      start = Time.now

      @data   = Array.new()
      threads = Array.new()

      awsData  = @cache.get( 'aws-data' )

      if( awsData == nil )

        awsData = @dataConsumer.instances()

        if( awsData.is_a?(Array) && awsData.count() != 0 )
          logger.debug( 'store data into cache' )
          @cache.set( 'aws-data' , expiresIn: 120 ) { Cache::Data.new( awsData ) }
        end

        @jobs.del( { :fqdn => 'foo' } )
        return

      else

        logger.debug( 'found cached AWS data' )
      end

      logger.debug( sprintf( 'AWS hold %d nodes', awsData.count ) )

#       logger.debug( JSON.pretty_generate( awsData ) )
      self.compareVersions( { 'live' => awsData } )

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

      @jobs.del( { :fqdn => 'foo' } )

      logger.debug( 'done' )

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
