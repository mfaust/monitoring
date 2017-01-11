
module Grafana

  module Coremedia

    module Dashboard


      # cae-live-1 -> cae-live
      def removePostfix( service )

        if( service =~ /\d/ )
          lastPart = service.split( '-' ).last
          service  = service.chomp( "-#{lastPart}" )
        end

        return service

      end


      def normalizeService( service )

        # normalize service names for grafana
        case service
          when 'content-management-server'
            service = 'CMS'
          when 'master-live-server'
            service = 'MLS'
          when 'replication-live-server'
            service = 'RLS'
          when 'workflow-server'
            service = 'WFS'
          when /^cae-live/
            service = 'CAE_LIVE'
          when /^cae-preview/
            service = 'CAE_PREV'
          when 'solr-master'
            service = 'SOLR_MASTER'
      #    when 'solr-slave'
      #      service = 'SOLR_SLAVE'
          when 'content-feeder'
            service = 'FEEDER_CONTENT'
          when 'caefeeder-live'
            service = 'FEEDER_LIVE'
          when 'caefeeder-preview'
            service = 'FEEDER_PREV'
        end

        return service.tr('-', '_').upcase

      end



      def prepare( host )

        dns = @db.dnsData( { :ip => host, :short => host } )

        if( dns != nil )
          dnsId        = dns[ :id ]
          dnsIp        = dns[ :ip ]
          dnsShortname = dns[ :shortname ]
          dnsLongname  = dns[ :longname ]
          dnsCreated   = dns[ :created ]
          dnsChecksum  = dns[ :checksum ]

          @shortHostname  = @grafanaHostname = dnsShortname

          config          = @db.config( { :ip => dnsIp, :key => 'display-name' } )

          if( config != false )
            @shortHostname = config.dig( dnsChecksum, 'display-name' ).first.to_s
          end

          @shortHostname        = @shortHostname.gsub( '.', '-' )

#           @discoveryFile        = sprintf( '%s/%s/discovery.json'       , @cacheDirectory, host )
#           @mergedHostFile       = sprintf( '%s/%s/mergedHostData.json'  , @cacheDirectory, host )
#           @monitoringResultFile = sprintf( '%s/%s/monitoring.result'    , @cacheDirectory, host )

        end


      end


      def createDashboardForHost( params = {} )

        host            = params[:host]     ? params[:host]     : nil
        @additionalTags = params[:tags]     ? params[:tags]     : []
        createOverview  = params[:overview] ? params[:overview] : false

        if( host == nil )

          logger.error( 'missing hostname to create Dashboards' )

          return {
            :status      => 500,
            :message     => 'missing hostname to create Dashboards'
          }
        end

        logger.info( sprintf( 'Adding dashboards for host \'%s\'', host ) )

        self.prepare( host )

        discovery = @db.discoveryData( { :ip => host, :short => host } )

        if( discovery == nil )
          return {
            :status    => 500,
            :message   => 'no discovery data found'
          }
        end

        services       = discovery.dig( host ).keys
        logger.debug( "Found services: #{services}" )
#         logger.debug( discovery )

        # fist, we must remove strange services
        servicesTmp = *services
        servicesTmp.delete( 'mysql' )
        servicesTmp.delete( 'postgres' )
        servicesTmp.delete( 'mongodb' )
        servicesTmp.delete( 'node_exporter' )
        servicesTmp.delete( 'demodata-generator' )

        measurements = @db.measurements( { :ip => host, :short => host } ).dig( host )

#         logger.debug(  measurements )

        services.each do |service|


          additionalTemplatePaths = Array.new()

          description    = discovery.dig( host, service, :data, 'description' )
          template       = discovery.dig( host, service, :data, 'template' )
          cacheKey       = Storage::Memcached.cacheKey( { :host => host, :pre => 'result', :service => service } )

          logger.debug( description )
#           logger.debug( template )
#           logger.debug( cacheKey )

          # cae-live-1 -> cae-live
          serviceName     = self.removePostfix( service )
          normalizedName  = self.normalizeService( service )

          templateName    = template != nil ? template : serviceName
          serviceTemplate = self.templateForService( serviceName )

          if( ! ['mongodb', 'mysql', 'postgres'].include?( serviceName ) )
            additionalTemplatePaths << self.templateForService( 'tomcat' )
          end

          if( ! serviceTemplate.to_s.empty? )

            logger.debug( sprintf( "Found Template paths: %s, %s" , serviceTemplate , additionalTemplatePaths ) )

            options = {
              :description             => description,
              :serviceName             => serviceName,
              :normalizedName          => normalizedName,
              :serviceTemplate         => serviceTemplate,
              :additionalTemplatePaths => additionalTemplatePaths
            }

            self.generateServiceTemplate( options )

          end
          logger.debug( '`---------------------------------------------------------' )
        end








      end




      def listDashboards( host )

        data = self.searchDashboards( { :tags   => host } )
        data = data.collect { |item| item['uri'] }
        data.each do |d|
          d.gsub!( sprintf( 'db/%s-', @shortHostname ), '' )
        end

        logger.debug( JSON.pretty_generate( data ) )

        data = self.searchDashboards( { :tags   => [ host, 'cae' ] } )
        logger.debug( JSON.pretty_generate( data ) )

        data = self.searchDashboards( { :tags   => [ 'cae' ] } )
        logger.debug( JSON.pretty_generate( data ) )


        data = self.searchDashboards( { :query => 'monitoring-16-01 - Cache Classes (CM)' } )
        logger.debug( JSON.pretty_generate( data ) )

        data = self.searchDashboards( { :starred => true } )
        logger.debug( JSON.pretty_generate( data ) )
      end






    end


    module Templates

      def templateForService( serviceName )

        template = sprintf( '%s/services/%s.json', @templateDirectory, serviceName )
        logger.debug( template )

        if( ! File.exist?( template ) )

          logger.error( sprintf( 'no template for service %s found', serviceName ) )

          template = nil
        end

        return template
      end


      def generateServiceTemplate( params = {} )

        description             = params[:description]             ? params[:description]             : nil
        serviceName             = params[:serviceName]             ? params[:serviceName]             : nil
        normalizedName          = params[:normalizedName]          ? params[:normalizedName]          : nil
        serviceTemplate         = params[:serviceTemplate]         ? params[:serviceTemplate]         : nil
        additionalTemplatePaths = params[:additionalTemplatePaths] ? params[:additionalTemplatePaths] : []

        logger.info( sprintf( 'Creating dashboard for \'%s\'', serviceName ) )
        logger.debug( sprintf( '  - template %s', File.basename( serviceTemplate ).strip ) )

        templateFile = File.read( serviceTemplate )
        templateJson = JSON.parse( templateFile )

        rows         = templateJson.dig( 'dashboards', 'rows' )

        if( rows != nil ) #templateJson.dig( 'dashboards', 'rows' ) ) # ['dashboard'] && templateJson['dashboard']['rows'] )

#          rows = templateJson['dashboard']['rows']

          additionalTemplatePaths.each do |additionalTemplate|

            logger.debug( sprintf( '  - merge with template %s', File.basename( additionalTemplate ).strip ) )

            additionalTemplateFile = File.read( additionalTemplate )
            additionalTemplateJson = JSON.parse( additionalTemplateFile )

            if( additionalTemplateJson['dashboard']['rows'] )
              templateJson['dashboard']['rows'] = additionalTemplateJson['dashboard']['rows'].concat(rows)
            end
          end
        end

        templateJson = self.addAnnotations( templateJson )
        json = JSON.generate( templateJson )



        json.gsub!( '%DESCRIPTION%', description )
        json.gsub!( '%SERVICE%'    , normalizedName )

        logger.debug( json )

#         self.sendTemplateToGrafana( json, normalizedName )

      end

    end




    module Annotations

      # add standard annotations to all Templates
      #
      #
      def addAnnotations( templateJson )

        # add or overwrite annotations
        annotations = '
          {
            "list": [
              {
                "name": "created",
                "enable": false,
                "iconColor": "rgb(93, 227, 12)",
                "datasource": "events",
                "tags": "%HOST% created&set=intersection"
              },
              {
                "name": "destoyed",
                "enable": false,
                "iconColor": "rgb(227, 57, 12)",
                "datasource": "events",
                "tags": "%HOST% destroyed&set=intersection"
              },
              {
                "name": "Load Tests",
                "enable": false,
                "iconColor": "rgb(26, 196, 220)",
                "datasource": "events",
                "tags": "%HOST% loadtest&set=intersection"
              },
              {
                "name": "Deployments",
                "enable": false,
                "iconColor": "rgb(176, 40, 253)",
                "datasource": "events",
                "tags": "%HOST% deployment&set=intersection"
              }
            ]
          }
        '

        if( templateJson.is_a?( String ) )
          templateJson = JSON.parse( templateJson )
        end

        annotation = templateJson.dig( 'dashboard', 'annotations' )

        if( annotation != nil )
          templateJson['dashboard']['annotations'] = JSON.parse( annotations )
        end

        return templateJson

      end

    end




    module Tags

      # expand the Template Tags
      #
      #
      #
      def addTags( templateJson )

        tags = @additionalTags

        # add tags
        if( templateJson.is_a?( String ) )
          templateJson = JSON.parse( templateJson )
        end

        currentTags = templateJson.dig( 'dashboard', 'tags' )

        if( currentTags != nil && tags != nil )

          currentTags << tags
          currentTags.flatten!.sort!

          templateJson['dashboard']['tags'] = currentTags
        end

        if( templateJson.is_a?( Hash ) )
          templateJson = JSON.generate( templateJson )
        end

        return templateJson

      end

    end


  end
end
