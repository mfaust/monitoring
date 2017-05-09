
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

        # get a DNS record
        #
        ip, short, fqdn = self.nsLookup( host )

        @shortHostname  = @grafanaHostname = short

        config          = @redis.config( { :short => short, :key => 'display-name' } )

        if( config.dig( 'display-name' ) != nil )

          @shortHostname = config.dig( 'display-name' ).to_s

          logger.info( "use custom display-name from config: '#{@shortHostname}'" )
        end

        @shortHostname        = self.createSlug( @shortHostname ).gsub( '.', '-' )

        logger.debug( @shortHostname )

#         dns = @redis.dnsData( { :ip => host, :short => host } )
#
#         if( dns != nil )
#
#           dnsIp        = dns.dig(:ip)
#           dnsShortname = dns.dig(:shortname)
#           dnsLongname  = dns.dig(:longname)
#
#           @shortHostname  = @grafanaHostname = dnsShortname
#
#           config          = @redis.config( { :short => dnsShortname, :key => 'display-name' } )
#
#           if( config.dig( 'display-name' ) != nil )
#
#             @shortHostname = config.dig( 'display-name' ).to_s
#
#             logger.info( "use custom display-name from config: '#{@shortHostname}'" )
#           end
#
#           @shortHostname        = self.createSlug( @shortHostname ).gsub( '.', '-' )
#         else
#
#           logger.warn( 'no DNS entry found' )
#         end

      end

      # creates an Grafana Dashboard for Coremedia Services
      # the Dashboard will be create from pre defined Templates
      # PUBLIC
      #
      # @param [Hash, #read] params the params for parameters
      # @option params [String] :host Filter for Hostname
      # @option params [String] :tags additional Tags
      # @option params [Bool] :overview create an Overview Dashboard
      #
      #
      def createDashboardForHost( params = {} )

        host            = params.dig(:host)
        @additionalTags = params.dig(:tags)     || []
        createOverview  = params.dig(:overview) || false

        if( host == nil )

          logger.error( 'missing hostname to create Dashboards' )

          return {
            :status      => 500,
            :message     => 'missing hostname to create Dashboards'
          }
        end

        start = Time.now

        logger.info( sprintf( 'Adding dashboards for host \'%s\'', host ) )

        self.prepare( host )

        discovery = @redis.discoveryData( { :short => host } )

        if( discovery == nil )
          return {
            :status    => 500,
            :message   => 'no discovery data found'
          }
        end

        services       = discovery.keys
        logger.debug( "Found services: #{services}" )

        # fist, we must remove strange services
        servicesTmp = *services
        servicesTmp.delete( 'mysql' )
        servicesTmp.delete( 'postgres' )
        servicesTmp.delete( 'mongodb' )
#         servicesTmp.delete( 'node_exporter' )
        servicesTmp.delete( 'demodata-generator' )

        serviceHash = Hash.new()

        discovery.each do |service,serviceData|

          logger.debug( service )
          logger.debug( serviceData )

          additionalTemplatePaths = Array.new()

          if( serviceData != nil )
            description    = serviceData.dig( 'description' )
            template       = serviceData.dig( 'template' )
          else
            description    = nil
            template       = nil
          end

          cacheKey       = Storage::RedisClient.cacheKey( { :host => host, :pre => 'result', :service => service } )

          # cae-live-1 -> cae-live
          serviceName     = self.removePostfix( service )
          normalizedName  = self.normalizeService( service )

          templateName    = template != nil ? template : serviceName
          serviceTemplate = self.templateForService( templateName )
#           serviceTemplate = self.templateForService( serviceName )

#           logger.debug( sprintf( '  serviceName  %s', serviceName ) )
#           logger.debug( sprintf( '  description  %s', description ) )
#           logger.debug( sprintf( '  template     %s', template ) )
#           logger.debug( sprintf( '  templateName %s', templateName ) )
#           logger.debug( sprintf( '  cacheKey     %s', cacheKey ) )

          if( ! ['mongodb', 'mysql', 'postgres', 'node_exporter'].include?( serviceName ) )
            additionalTemplatePaths << self.templateForService( 'tomcat' )
          end

          if( ! serviceTemplate.to_s.empty? )

            options = {
              :description             => description,
              :serviceName             => serviceName,
              :normalizedName          => normalizedName,
              :serviceTemplate         => serviceTemplate,
              :additionalTemplatePaths => additionalTemplatePaths
            }

            self.createServiceTemplate( options )

          end

        end

        # we want an Services Overview for this Host
        if( createOverview == true )
          self.createOverview( services ) # add description
        end


        # named Templates are a subset of specialized Templates
        # like Memory-Pools, Tomcat or simple Grafana-Templates
        namedTemplate = Array.new()

        # MemoryPools for many Services
        namedTemplate.push( 'cm-memory-pool.json' )

        # unique Tomcat Dashboard
        namedTemplate.push( 'cm-tomcat.json' )

        # CAE Caches
        if( servicesTmp.include?( 'cae-preview' ) || servicesTmp.include?( 'cae-live' ) )

          namedTemplate.push( 'cm-cae-cache-classes.json' )

          if( @mbean.beanAvailable?( host, 'cae-preview', 'CacheClassesECommerceAvailability' ) == true )
            namedTemplate.push( 'cm-cae-cache-classes-ibm.json' )
          end
        end

        # add Operation Datas for NodeExporter
        if( servicesTmp == 'node_exporter' )
          namedTemplate.push( 'cm-node_exporter.json' )
        end

        self.createNamedTemplate( namedTemplate )

        measurements = nil

        begin

          for y in 1..30

            result = @redis.measurements( { :short => host } )

            if( result != nil )
              measurements = result
              break
            else
              logger.debug( sprintf( 'wait for measurements data for node \'%s\' ... %d', host, y ) )
              sleep( 4 )
            end
          end

#           until( measurements != nil )
#
#             logger.debug( sprintf( 'wait for measurements data for node \'%s\'', host ) )
#
#             measurements = @redis.measurements( { :short => host } )
#             sleep( 8 )
#           end

        rescue => e
          logger.error( e )
        end

        # - at last - the LicenseInformation
        if( servicesTmp.include?( 'content-management-server' ) ||
            servicesTmp.include?( 'master-live-server' ) ||
            servicesTmp.include?( 'replication-live-server' ) )
          self.createLicenseTemplate( { :host => host, :services => services } )
        end

        dashboards = self.listDashboards( { :host => @shortHostname } )
        dashboards = dashboards.dig(:dashboards)

        if( dashboards == nil )

          return {
            :status      => 500,
            :message     => 'no dashboards added'
          }
        end

        count      = dashboards.count()

        if( count.to_i != 0 )
          status  = 200
          message = sprintf( '%d dashboards added', count )
        else
          status  = 500
          message = 'Error for adding Dashboads'
        end

        finish = Time.now
        logger.info( sprintf( 'finished in %s seconds', finish - start ) )

        return {
          :status      => status,
          :name        => host,
          :message     => message
        }

      end


      def createOverview( services = [] )

        logger.info( 'Create Overview Template' )

        rows = self.overviewTemplateRows( services )
        rows = rows.join(',')

        template = %(
          {
            "dashboard": {
              "id": null,
              "title": "%SHORTHOST% = Overview",
              "originalTitle": "%SHORTHOST% = Overview",
              "tags": [ "%TAG%", "overview" ],
              "style": "dark",
              "timezone": "browser",
              "editable": true,
              "hideControls": false,
              "sharedCrosshair": false,
              "rows": [
                #{rows}
              ],
              "time": {
                "from": "now-2m",
                "to": "now"
              },
              "timepicker": {
                "refresh_intervals": [ "30s", "1m", "2m" ],
                "time_options": [ "1m", "3m", "5m", "15m" ]
              },
              "templating": {
                "list": []
              },
              "annotations": {
                "list": []
              },
              "refresh": "1m",
              "schemaVersion": 12,
              "version": 0,
              "links": []
            }
          }
        )

        json = self.normalizeTemplate( {
          :template        => template,
          :grafanaHostname => @shortHostname,
          :shortHostname   => @shortHostname
        } )

        response = self.postRequest( '/api/dashboards/db' , json )

      end


      def createLicenseTemplate( params = {} )

        logger.info( 'create License Templates' )

        host            = params[:host]     ? params[:host]     : nil
        services        = params[:services] ? params[:services] : []

        rows            = Array.new()
        contentServers  = ['content-management-server', 'master-live-server', 'replication-live-server']
        intersect       = contentServers & services

#         logger.debug( " contentServers: #{contentServers}" )
#         logger.debug( " services      : #{services}" )
#         logger.debug( " use           : #{intersect}" )

        licenseHead    = sprintf( '%s/licenses/licenses-head.json' , @templateDirectory )
        licenseUntil   = sprintf( '%s/licenses/licenses-until.json', @templateDirectory )
        licensePart    = sprintf( '%s/licenses/licenses-part.json' , @templateDirectory )

        intersect.each do |service|

          if( @mbean.beanAvailable?( host, service, 'Server', 'LicenseValidUntilHard' ) == true )

            logger.info( sprintf( 'found License Information for Service %s', service ) )

            if( File.exist?( licenseUntil ) )

              tpl = File.read( licenseUntil )

              tpl.gsub!( '%SERVICE%', normalizeService( service ) )

              rows << tpl
            end

          end
        end

        if( File.exist?( licenseHead ) )
          rows << File.read( licenseHead )
        end

        intersect.each do |service|

          if( @mbean.beanAvailable?( host, service, 'Server', 'ServiceInfos' ) == true )

            logger.info( sprintf( 'found Service Information for Service %s', service ) )

            if( File.exist?( licensePart ) )

              tpl = File.read( licensePart )

              tpl.gsub!( '%SERVICE%', normalizeService( service ) )

              if( service == 'replication-live-server' )

                tpl.gsub!( 'Server.ServiceInfo.publisher' , 'Server.ServiceInfo.webserver' )
                tpl.gsub!( 'Publisher', 'Webserver' )

              end

              rows << tpl
            end
          end
        end

        if( rows.count == 1 )
          # only the license Head is into the array
          logger.info( 'We have no information about Licenses' )
          return
        end

        rows = rows.join(',')

        template = %(
          {
            "dashboard": {
              "id": null,
              "title": "%SHORTHOST% - Licenses",
              "originalTitle": "%SHORTHOST% - Licenses",
              "tags": [ "%TAG%", "licenses" ],
              "style": "dark",
              "timezone": "browser",
              "editable": true,
              "hideControls": false,
              "sharedCrosshair": false,
              "rows": [
                #{rows}
              ],
              "time": {
                "from": "now-2m",
                "to": "now"
              },
              "timepicker": {
                "refresh_intervals": [ "1m", "2m", "10m" ],
                "time_options": [ "2m", "15m" ]
              },
              "templating": {
                "list": []
              },
              "annotations": {
                "list": []
              },
              "refresh": "2m",
              "schemaVersion": 12,
              "version": 0,
              "links": []
            }
          }
        )

        json = self.normalizeTemplate( {
          :template        => template,
          :grafanaHostname => @shortHostname,
          :shortHostname   => @shortHostname
        } )

        self.postRequest( '/api/dashboards/db' , json )

      end


      # use array to add more than on template
      def createNamedTemplate( templates = [] )

        logger.info( 'add named template' )

        if( templates.count() != 0 )

          templates.each do |template|

            filename = sprintf( '%s/%s', @templateDirectory, template )

            if( File.exist?( filename ) )

              logger.info( sprintf( '  - %s', File.basename( filename ).strip ) )

#             file = File.read( filename )
#             file = self.addAnnotations( file )
#             file = JSON.generate( file )

              templateJson = self.addAnnotations( File.read( filename ) )

              json = self.normalizeTemplate( {
                :template        => templateJson,
                :grafanaHostname => @shortHostname,
                :shortHostname   => @shortHostname
              } )

              self.postRequest( '/api/dashboards/db' , json )

            end
          end
        end
      end


      # List Grafana Dashboards
      # PUBLIC
      #
      # @param [Hash, #read] params the params for parameters
      # @option params [String] :host Filter for Hostname
      # @option params [String] :query A Dashboard Description
      # @option params [Bool] :starred starred Dashbaoards
      # @option params [Array] :tags an Array ob Tags
      # @example For an successful Login
      #    searchDashboards( { :tags   => [ host, 'foo1' ] } )
      #    searchDashboards( { :tags   => [ 'foo1' ] } )
      #    searchDashboards( { :starred => true } )
      #    searchDashboards( { :query => 'Dashboard for Tomcats' } )
      #    or, in combination
      #    searchDashboards( { :tags => [ 'dev' ], :starred => true, :query => 'Dashboard for Tomcats' } )
      # @return [Hash, #read]
      def listDashboards( params = {} )

        host            = params.dig(:host)

        data = self.searchDashboards( { :tags   => host } )

        if( data == nil || data == false )

          return {
            :status     => 204,
            :message    => 'no Dashboards found'
          }
        end

        data = data.collect { |item| item['uri'] }

        data.each do |d|
          d.gsub!( sprintf( 'db/%s-', host ), '' )
        end

        if( data.count == 0 )

          return {
            :status     => 204,
            :message    => 'no Dashboards found'
          }
        end

        return {
          :status     => 200,
          :count      => data.count,
          :dashboards => data
        }
      end


      def deleteDashboards( params = {} )

        host = params.dig(:host)
        tags = params.dig(:tags) || []

        if( host == nil )

          logger.error( 'missing hostname to delete Dashboards' )

          return {
            :status      => 500,
            :message     => 'missing hostname to delete Dashboards'
          }
        end

        logger.info( sprintf( 'remove dashboards for host %s', host ) )

        self.prepare( host )

        dashboards = self.listDashboards( { :host => host } )
        dashboards = dashboards.dig(:dashboards)

        if( dashboards == nil )

          return {
            :status      => 500,
            :message     => 'no dashboards found'
          }

        end

        count      = dashboards.count()

        if( count.to_i == 0 )

          return {
            :status      => 204,
            :name        => host,
            :message     => 'No Dashboards found'
          }
        else

#           logger.debug( sprintf( 'found %d dashboards for delete', count ) )

          dashboards.each do |d|

            # TODO
            #if( (i.include?"group") && ( !host.include?"group") )
            #  # Don't delete group templates except if deletion is forced
            #  next
            #end

#             logger.debug( sprintf( '  - %s', d ) )

            response = self.deleteRequest( sprintf( '/api/dashboards/db/%s-%s', host, d ) )
          end

          logger.info( sprintf( '%d dashboards deleted', count ) )

          return {
            :status      => 200,
            :name        => host,
            :message     => sprintf( '%d dashboards deleted', count )
          }

        end
      end

    end


    module Templates

      def templateForService( serviceName )

        # TODO
        # look for '%s/%s.json'  and  '%s/services/%s.json'
        # first match wins

        template      = nil
        templateArray = Array.new()

        templateArray << sprintf( '%s/%s.json', @templateDirectory, serviceName )
        templateArray << sprintf( '%s/services/%s.json', @templateDirectory, serviceName )

        templateArray.each do |tpl|

          if( File.exist?( tpl ) )

#             logger.debug( sprintf( '  => found %s', tpl ) )
            template = tpl
            break
          end
        end

        if( template == nil )

          logger.error( sprintf( 'no template for service %s found', serviceName ) )
        end

        return template

      end


      def createServiceTemplate( params = {} )

        description             = params.dig(:description)
        serviceName             = params.dig(:serviceName)
        normalizedName          = params.dig(:normalizedName)
        serviceTemplate         = params.dig(:serviceTemplate)
        additionalTemplatePaths = params.dig(:additionalTemplatePaths) || []

        logger.info( sprintf( 'Creating dashboard for \'%s\'', serviceName ) )

        templateFile = File.read( serviceTemplate )
        templateJson = JSON.parse( templateFile )

        rows         = templateJson.dig( 'dashboard', 'rows' )

        if( rows != nil )

          additionalTemplatePaths.each do |additionalTemplate|

            additionalTemplateFile = File.read( additionalTemplate )
            additionalTemplateJson = JSON.parse( additionalTemplateFile )

            if( additionalTemplateJson['dashboard']['rows'] )
              templateJson['dashboard']['rows'] = additionalTemplateJson['dashboard']['rows'].concat(rows)
            end
          end
        end

        templateJson = self.addAnnotations( templateJson )

        json = self.normalizeTemplate( {
          :template        => templateJson,
          :serviceName     => serviceName,
          :description     => description,
          :normalizedName  => normalizedName,
          :grafanaHostname => @shortHostname,
          :shortHostname   => @shortHostname
        } )

        response = self.postRequest( '/api/dashboards/db' , json )

      end


      def overviewTemplateRows( services = [] )

        rows = Array.new()
        dir  = Array.new()
        srv  = Array.new()

        services.each do |s|
          srv << self.removePostfix( s )
        end

        regex = /
          ^                       # Starting at the front of the string
          \d\d-                   # 2 digit
          (?<service>.+[a-zA-Z0-9])  # service name
          \.tpl                   #
        /x

        Dir.chdir( sprintf( '%s/overview', @templateDirectory )  )

        dirs = Dir.glob( "**.tpl" ).sort

#        dirs.sort!

        dirs.each do |f|

          if( f =~ regex )
            part = f.match(regex)
            dir << part['service'].to_s.strip
          end
        end

        # TODO
        # add overwriten templates!
        intersect = dir & srv

        intersect.each do |service|

#           service  = removePostfix( service )
          template = Dir.glob( sprintf( '%s/overview/**%s.tpl', @templateDirectory, service ) ).first

          if( File.exist?( template ) )

            tpl = File.read( template )
            rows << tpl
          end
        end

#         logger.debug( " templates: #{dirs}" )
#         logger.debug( " services : #{srv}" )
#         logger.debug( " use      : #{intersect}" )

        return rows

      end


      def normalizeTemplate( params = {} )

        template        = params[:template]        ? params[:template]        : nil
        serviceName     = params[:serviceName]     ? params[:serviceName]     : nil
        description     = params[:description]     ? params[:description]     : nil
        normalizedName  = params[:normalizedName]  ? params[:normalizedName]  : nil
        grafanaHostname = params[:grafanaHostname] ? params[:grafanaHostname] : nil
        shortHostname   = params[:shortHostname]   ? params[:shortHostname]   : nil

        if( template == nil )
          return false
        end

        if( template.is_a?( Hash ) )
          template = JSON.generate( template )
        end

#         if( serviceName )
#           template.gsub!( '%SERVICE%'  , serviceName )
#         end

        # replace Template Vars
        map = {
          '%DESCRIPTION%' => description,
          '%SERVICE%'     => normalizedName,
          '%HOST%'        => grafanaHostname,
          '%SHORTHOST%'   => shortHostname,
          '%TAG%'         => shortHostname
        }

        re = Regexp.new( map.keys.map { |x| Regexp.escape(x) }.join( '|' ) )

        template.gsub!( re, map )

        if( @additionalTags.count() > 0 )
          template = self.addTags( { :template => template, :additionalTags => @additionalTags } )
        end

        # now we must recreate *all* panel IDs for an propper import
        template = JSON.parse( template )

        rows = template.dig( 'dashboard', 'rows' )

        if( rows != nil )

          counter   = 1
          idCounter = 10

          rows.each_with_index do |r, counter|

            panel = r.dig('panels')
            panel.each do |p|
              p['id']   = idCounter
              idCounter += 1 # idCounter +=1 ??
            end
          end
        end

        return JSON.generate( template )

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
      def addTags( params = {} )

        template        = params[:template]        ? params[:template]        : nil
        additionalTags  = params[:additionalTags]  ? params[:additionalTags]  : []

        # add tags
        if( template.is_a?( String ) )
          template = JSON.parse( template )
        end

        if( additionalTags.is_a?( Hash ) )

          additionalTags = additionalTags.values
        end

        currentTags = template.dig( 'dashboard', 'tags' )

        if( currentTags != nil && additionalTags.count() > 0 )

          currentTags << additionalTags

          currentTags.flatten!
          currentTags.sort!

          template['dashboard']['tags'] = currentTags
        end

        if( template.is_a?( Hash ) )
          template = JSON.generate( template )
        end

        return template

      end

    end


  end
end
