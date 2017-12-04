
class CMGrafana

  module CoreMedia

    module Dashboard


      def prepare( host )

        # get a DNS record
        #
        ip, short, fqdn = self.ns_lookup(host )

        @short_hostname     = short  # (%HOST%)
        @grafana_hostname   = fqdn   # name for the grafana title (%SHORTNAME%)
        @storage_identifier = fqdn   # identifier for an storage path (%STORAGE_IDENTIFIER%) (useful for cloud stack on aws with changing hostnames)

        # read the configuration for an customized display name
        #
        display     = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'display_name' )
        identifier  = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'graphite_identifier' )

        if( display != nil && display.dig( 'display_name' ) != nil )

          @grafana_hostname = display.dig( 'display_name' ).to_s
          logger.info( "use custom display_name from config: '#{@grafana_hostname}'" )
        end


        if( identifier != nil && identifier.dig( 'graphite_identifier' ) != nil )

          @storage_identifier = identifier.dig( 'graphite_identifier' ).to_s
          logger.info( "use custom storage identifier from config: '#{@storage_identifier}'" )
        end

        @grafana_hostname  = slug( @grafana_hostname ).gsub( '.', '-' )

        logger.debug( format('ip   : %s', ip))
        logger.debug( format('short: %s', short))
        logger.debug( format('fqdn : %s', fqdn))
        logger.debug( "short hostname    : #{@short_hostname}" )
        logger.debug( "grafana hostname  : #{@grafana_hostname}" )
        logger.debug( "storage Identifier: #{@storage_identifier}" )

        return ip, short, fqdn
      end

      # creates an Grafana Dashboard for CoreMedia Services
      # the Dashboard will be create from pre defined Templates
      # PUBLIC
      #
      # @param [Hash, #read] params the params for parameters
      # @option params [String] :host Filter for Hostname
      # @option params [String] :tags additional Tags
      # @option params [Bool] :overview create an Overview Dashboard
      #
      #
      def create_dashboard_for_host(params = {} )

        host            = params.dig(:host)
        @additional_tags = params.dig(:tags)     || []
        create_overview  = params.dig(:overview) || false

        if( host.nil? )
          logger.error( 'missing hostname to create Dashboards' )
          return { status: 500, message: 'missing hostname to create Dashboards' }
        end

        start = Time.now

        logger.info( sprintf( 'Adding dashboards for host \'%s\'', host ) )

        ip, short, fqdn = self.prepare( host )

        discovery = discovery_data( ip: ip, short: short, fqdn: fqdn )

        return { status: 400, message: 'no discovery data found' } if( discovery.nil? )

        services       = discovery.keys
        logger.debug( "Found services: #{services}" )

        # fist, we must remove strange services
        tmp_services = *services
        tmp_services.delete( 'mysql' )
        tmp_services.delete( 'postgres' )
        tmp_services.delete( 'mongodb' )
#        tmp_services.delete( 'node-exporter' )
        tmp_services.delete( 'demodata-generator' )
        tmp_services.delete( 'http-proxy' )
        tmp_services.delete( 'https-proxy' )
        tmp_services.delete( 'http-status' )

        # ensure, that we are logged in
        login( user: @user, password: @password, max_retries: 10 )

        # we want an Services Overview for this Host
        create_overview( services ) if(create_overview) # add description

        discovery.each do |service,service_data|

          additional_template_paths = Array.new

          if( service_data != nil )
            description    = service_data.dig( 'description' )
            template       = service_data.dig( 'template' )
          else
            description    = nil
            template       = nil
          end

          # cae-live-1 -> cae-live
          service_name     = self.remove_postfix( service )
          normalized_name  = self.normalize_service( service )

          template_name    = template != nil ? template : service_name
          service_template = self.template_for_service( template_name )
#           service_template = self.template_for_service( service_name )

#           logger.debug( sprintf( '  service_name  %s', service_name ) )
#           logger.debug( sprintf( '  description  %s', description ) )
#           logger.debug( sprintf( '  template     %s', template ) )
#           logger.debug( sprintf( '  template_name %s', template_name ) )
#           logger.debug( sprintf( '  cache_key     %s', cache_key ) )

          if( ! %w(mongodb mysql postgres node-exporter http-status).include?( service_name ) )
            additional_template_paths << self.template_for_service( 'tomcat' )
          end

          if( ! service_template.to_s.empty? )

            options = {
              description: description,
              service_name: service_name,
              normalized_name: normalized_name,
              service_template: service_template,
              additional_template_paths: additional_template_paths
            }

            self.create_service_template( options )
          end
        end

        # named Templates are a subset of specialized Templates
        # like Memory-Pools, Tomcat or simple Grafana-Templates
        named_template_array = Array.new

        # MemoryPools for many Services
        named_template_array.push( 'cm-memory-pool.json' )

        # unique Tomcat Dashboard
        named_template_array.push( 'cm-tomcat.json' )

        # CAE Caches
        if( tmp_services.include?( 'cae-preview' ) || tmp_services.include?( 'cae-live' ) )

          named_template_array.push( 'cm-cae-cache-classes.json' )
          named_template_array.push( 'cm-cae-cache-classes-ecommerce.json' ) if(@mbean.beanAvailable?(host, 'cae-preview', 'CacheClassesECommerceAvailability'))
        end

        # add Operation Datas for NodeExporter
        named_template_array.push( 'cm-node-exporter.json' ) if( services.include?('node-exporter' ) )
        named_template_array.push( 'cm-http-status.json' ) if( services.include?('http-status' ) )

        self.create_named_template( named_template_array )

        begin
          (1..30).each { |y|

            result = @redis.measurements( short: short, fqdn: fqdn )

            if( result.nil? )
              logger.debug(sprintf('wait for measurements data for node \'%s\' ... %d', short, y))
              sleep(4)
            else
              break
            end
          }

        rescue => e
          logger.error( e )
        end

        # - at last - the LicenseInformation
        if( tmp_services.include?( 'content-management-server' ) ||
            tmp_services.include?( 'master-live-server' ) ||
            tmp_services.include?( 'replication-live-server' ) )

          # TODO
          # check ASAP if FQDN needed!
          create_license_template( host: fqdn, services: services )
        end

        dashboards = self.list_dashboards( host: short ) #@grafana_hostname } )
        dashboards = dashboards.dig(:dashboards)

        # TODO
        # clearer!
        return { status: 404, message: 'no dashboards added' } if( dashboards.nil? )

        count      = dashboards.count

        if( count.to_i != 0 )
          status  = 200
          message = sprintf( '%d dashboards added', count )
        else
          status  = 404
          message = 'Error for adding Dashboads'
        end

        finish = Time.now
        logger.info( sprintf( 'finished in %s seconds', (finish - start).round(2) ) )

        { status: status, name: host, message: message  }
      end


      def create_overview( services = [] )

        logger.info( 'Create Overview Template' )

        rows = self.overview_template_rows(services )
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
                "list": [
                  {
                    "current": {
                      "value": "%STORAGE_IDENTIFIER%",
                      "text": "%STORAGE_IDENTIFIER%"
                    },
                    "hide": 2,
                    "label": null,
                    "name": "host",
                    "options": [
                      {
                        "value": "%STORAGE_IDENTIFIER%",
                        "text": "%STORAGE_IDENTIFIER%"
                      }
                    ],
                    "query": "%STORAGE_IDENTIFIER%",
                    "type": "constant"
                  }
                ]
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

        json = self.normalize_template({
          :template          => template,
          :grafana_hostname   => @grafana_hostname,
          :storage_identifier => @storage_identifier,
          :short_hostname     => @short_hostname
        } )

        json = JSON.parse( json ) if( json.is_a?(String) )
        title = json.dig('dashboard','title')

        response = create_dashboard( title: title, dashboard: json )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
      end


      def create_license_template(params = {} )

        logger.info( 'create License Templates' )

        host            = params.dig(:host)
        services        = params.dig(:services) || []

        rows            = Array.new
        content_servers  = %w(content-management-server master-live-server replication-live-server)
        intersect       = content_servers & services

        license_head    = sprintf( '%s/licenses/licenses-head.json' , @template_directory )
        license_until   = sprintf( '%s/licenses/licenses-until.json', @template_directory )
        license_part    = sprintf( '%s/licenses/licenses-part.json' , @template_directory )

        intersect.each do |service|

          logger.debug( format( 'Search License Information for Service %s', service ) )

          bean_available = @mbean.beanAvailable?(host, service, 'Server', 'LicenseValidUntilHard')

#           logger.debug( "#{bean_available}" )
#           logger.debug('---------')

          if( bean_available )

            logger.info( sprintf( '  - found License Information for Service %s', service ) )

            if( File.exist?( license_until ) )

              tpl = File.read( license_until )

              tpl.gsub!( '%SERVICE%', normalize_service( service ) )

              rows << tpl
            end

          end
        end

        rows << File.read( license_head )  if( File.exist?( license_head ) )

        intersect.each do |service|

          logger.debug( format( 'Search Service Information for Service %s', service ) )

          bean_available = @mbean.beanAvailable?(host, service, 'Server', 'ServiceInfos')

#           logger.debug( "#{bean_available}" )
#           logger.debug('---------')

          if( bean_available )

            logger.info( sprintf( '  - found Service Information for Service %s', service ) )

            if( File.exist?( license_part ) )

              tpl = File.read( license_part )

              tpl.gsub!( '%SERVICE%', normalize_service( service ) )

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
          logger.info( 'we have no information about licenses' )
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
                "list": [
                  {
                    "current": {
                      "value": "%STORAGE_IDENTIFIER%",
                      "text": "%STORAGE_IDENTIFIER%"
                    },
                    "hide": 2,
                    "label": null,
                    "name": "host",
                    "options": [
                      {
                        "value": "%STORAGE_IDENTIFIER%",
                        "text": "%STORAGE_IDENTIFIER%"
                      }
                    ],
                    "query": "%STORAGE_IDENTIFIER%",
                    "type": "constant"
                  }
                ]
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

        json = self.normalize_template({
          :template          => template,
          :grafana_hostname   => @grafana_hostname,
          :storage_identifier => @storage_identifier,
          :short_hostname     => @short_hostname
        } )

        json = JSON.parse( json ) if( json.is_a?(String) )
        title = json.dig('dashboard','title')

        response = create_dashboard( title: title, dashboard: json )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
      end


      # use array to add more than on template
      def create_named_template( templates = [] )

        logger.info( 'add named template' )

        if( templates.count != 0 )

          templates.each do |template|

            filename = sprintf( '%s/%s', @template_directory, template )

            if( File.exist?( filename ) )

              logger.info( sprintf( '  - %s', File.basename( filename ).strip ) )

              # TODO
              # switch to gem
              template_json = self.add_annotations(File.read(filename ) )

              json = self.normalize_template({
                :template          => template_json,
                :grafana_hostname   => @grafana_hostname,
                :storage_identifier => @storage_identifier,
                :short_hostname     => @short_hostname
              } )

              json = JSON.parse( json ) if( json.is_a?(String) )
              title = json.dig('dashboard','title')
              logger.debug( title )

              response = create_dashboard( title: title, dashboard: json )
              response_status  = response.dig('status').to_i
              response_message = response.dig('message')

              logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
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
      def list_dashboards( params )

        logger.debug("list_dashboards( #{params} )")

        tags            = params.dig(:tags)

        # ensure, that we are logged in
        login( user: @user, password: @password, max_retries: 10 )

        data = self.search_dashboards( tags: tags )
        data = data.dig('message') unless( data.nil? )

        return { status: 204, message: 'no Dashboards found' } if( data.nil? || data == false || data.count == 0 )

        # get all elements from type 'uri'
        # and remove the path and the tag-name'
        data = data.collect { |item| item['uri'] }

        # db/blueprint-box-cache-classes-cm => blueprint-box-cache-classes-cm
        data.each do |d|
          # d.gsub!( sprintf( 'db/%s-', tags ), '' )
          d.gsub!( 'db/', '' )
        end

        { status: 200, count: data.count, dashboards: data }
      end


      def delete_dashboards( params )

        host = params.dig(:host)
        fqdn = params.dig(:fqdn)
        tags = params.dig(:tags) || []

        if( host.nil? )
          logger.error( 'missing hostname to delete Dashboards' )
          return { status: 500, message: 'missing hostname to delete Dashboards' }
        end

        ip, short, fqdn = self.prepare( host )

        dashboards = self.list_dashboards( tags: short )

        status = dashboards.dig(:status)

        return { status: 204, name: host, message: 'no Dashboards found' } if( status.to_i == 204 )

        if( status.to_i == 200 )

          dashboards = dashboards.dig(:dashboards)

          return { status: 500, message: 'no dashboards found' } if( dashboards.nil? )

          count      = dashboards.count

          return { status: 204, name: host, message: 'no Dashboards found' } if( count.to_i == 0 )

          delete_count = 0

          logger.info( sprintf( 'remove %d dashboards for host %s (%s)', count, host, @grafana_hostname ) )
#           logger.debug( sprintf( 'found %d dashboards for delete', count ) )

          # ensure, that we are logged in
          login( user: @user, password: @password, max_retries: 10 )

          dashboards.each do |d|

            # TODO
            #if( (i.include?"group") && ( !host.include?"group") )
            #  # Don't delete group templates except if deletion is forced
            #  next
            #end

            logger.debug( sprintf( '  - %s :: %s', host, d ) )

            response = delete_dashboard( d )

            logger.debug( response )

            status = response.dig('status')

            delete_count += 1 if( status == 200 )

          end

          logger.info( sprintf( '%d dashboards deleted', delete_count ) )

          return { status: 200, name: host, message: sprintf( '%d dashboards deleted', delete_count ) }
        end

      end


      def update_dashboards( params )

        host             = params.dig(:host)
        @additional_tags = params.dig(:tags)     || []
        create_overview  = params.dig(:overview) || false

        ip, short, fqdn  = prepare( host )

        overview_dashboard = list_dashboards( tags: [ short, 'overview' ] )
        licenses_dashboard = list_dashboards( tags: [ short, 'licenses' ] )

        overview_dashboard = overview_dashboard.dig(:dashboards)
        licenses_dashboard = licenses_dashboard.dig(:dashboards)

        params[:overview] = true if(overview_dashboard)

        logger.debug( "overview_dashboard: #{overview_dashboard}" )

        logger.debug( 'first, delete combined dashboards: overview and licenses' )
        overview_dashboard.each do |d|
          logger.debug( sprintf( '  - %s :: %s', host, d ) )
          response = delete_dashboard( d )
          # logger.debug( response )
          status = response.dig('status')
        end

        licenses_dashboard.each do |d|
          logger.debug( sprintf( '  - %s :: %s', host, d ) )
          response = delete_dashboard( d )
          # logger.debug( response )
          status = response.dig('status')
        end

        create_dashboard_for_host( params )
      end


    end


    module Templates

      def template_for_service( service_name )

        # TODO
        # look for '%s/%s.json'  and  '%s/services/%s.json'
        # first match wins

        template      = nil
        template_array = Array.new

        template_array << sprintf( '%s/%s.json', @template_directory, service_name )
        template_array << sprintf( '%s/services/%s.json', @template_directory, service_name )

        template_array.each do |tpl|

          if( File.exist?( tpl ) )

#             logger.debug( sprintf( '  => found %s', tpl ) )
            template = tpl
            break
          end
        end

        logger.warn( sprintf( 'no template for service %s found', service_name ) ) if( template.nil? )

        template
      end


      def create_service_template( params )

        description             = params.dig(:description)
        service_name             = params.dig(:service_name)
        normalized_name          = params.dig(:normalized_name)
        service_template         = params.dig(:service_template)
        additional_template_paths = params.dig(:additional_template_paths) || []
        mls_identifier           = @storage_identifier

        logger.info( sprintf( 'Creating dashboard for \'%s\'', service_name ) )

        if( service_name == 'replication-live-server' )

          logger.info( '  search Master Live Server IOR for the Replication Live Server' )

          # 'Server'
          ip, short, fqdn = self.ns_lookup(@short_hostname )

          bean = @mbean.bean( fqdn, service_name, 'Replicator' )

          if( bean != nil && bean != false )

            value = bean.dig( 'value' )
            if( value != nil )

              value = value.values.first

              mls = value.dig( 'MasterLiveServer', 'host' )

              if( mls != nil )

                ip, short, fqdn = self.ns_lookup(mls )

                dns = @database.dnsData( { :ip => ip, :short => short, :fqdn => fqdn } )

                real_ip    = dns.dig('ip')
                real_short = dns.dig('name')
                real_fqdn  = dns.dig('fqdn')

                if( @short_hostname != real_short )

                  identifier  = @database.config( { :ip => real_ip, :short => real_short, :fqdn => real_fqdn, :key => 'graphite_identifier' } )

                  if( identifier.dig( 'graphite_identifier' ) != nil )

                    mls_identifier = identifier.dig( 'graphite_identifier' ).to_s

                    logger.info( "  use custom storage identifier from config: '#{mls_identifier}'" )
                  end
                else
                  logger.info( '  the Master Live Server runs on the same host as the Replication Live Server' )
                end
              end
            end
          end
        end

        template_file = File.read( service_template )
        template_json = JSON.parse( template_file )

        rows         = template_json.dig( 'dashboard', 'rows' )

        if( rows != nil )

          additional_template_paths.each do |additionalTemplate|

            additional_template_file = File.read( additionalTemplate )
            additional_template_json = JSON.parse( additional_template_file )

            if( additional_template_json['dashboard']['rows'] )
              template_json['dashboard']['rows'] = additional_template_json['dashboard']['rows'].concat(rows)
            end
          end
        end

        # TODO
        # switch to gem
        template_json = self.add_annotations(template_json )

        json = self.normalize_template({
          :template          => template_json,
          :service_name       => service_name,
          :description       => description,
          :normalized_name    => normalized_name,
          :grafana_hostname   => @grafana_hostname,
          :storage_identifier => @storage_identifier,
          :short_hostname     => @short_hostname,
          :mls_identifier     => mls_identifier
        } )

        json = JSON.parse( json ) if( json.is_a?(String) )
        title = json.dig('dashboard','title')

        # TODO
        # check, if dashboard exists
        # check, if we can overwrite the dashboard
        response = create_dashboard( title: title, dashboard: json )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )

      end


      def overview_template_rows(services = [] )

        rows = Array.new
        dir  = Array.new
        srv  = Array.new

        services.each do |s|
          srv << self.remove_postfix( s )
        end

        regex = /
          ^                       # Starting at the front of the string
          \d\d-                   # 2 digit
          (?<service>.+[a-zA-Z0-9])  # service name
          \.tpl                   #
        /x

        Dir.chdir( sprintf( '%s/overview', @template_directory )  )

        dirs = Dir.glob( '**.tpl' ).sort

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

#           service  = remove_postfix( service )
          template = Dir.glob( sprintf( '%s/overview/**%s.tpl', @template_directory, service ) ).first

          if( File.exist?( template ) )

            tpl = File.read( template )
            rows << tpl
          end
        end

#         logger.debug( " templates: #{dirs}" )
#         logger.debug( " services : #{srv}" )
#         logger.debug( " use      : #{intersect}" )

        rows

      end


      def normalize_template(params = {} )

        template           = params.dig(:template)
        service_name       = params.dig(:service_name)
        description        = params.dig(:description)
        normalized_name    = params.dig(:normalized_name)
        grafana_hostname   = params.dig(:grafana_hostname)
        storage_identifier = params.dig(:storage_identifier)
        short_hostname     = params.dig(:short_hostname)
        mls_identifier     = params.dig(:mls_identifier)

        if( template.nil? )
          return false
        end

        if( template.is_a?( Hash ) )
          template = JSON.generate( template )
        end

        # replace Template Vars
        map = {
          '%DESCRIPTION%'            => description,
          '%SERVICE%'                => normalized_name,
          '%HOST%'                   => short_hostname,
          '%SHORTHOST%'              => grafana_hostname,
          '%STORAGE_IDENTIFIER%'     => storage_identifier,
          '%ICINGA_IDENTIFIER%'      => storage_identifier.gsub('.','_'),
          '%MLS_STORAGE_IDENTIFIER%' => mls_identifier,
          '%TAG%'                    => short_hostname
        }

        re = Regexp.new( map.keys.map { |x| Regexp.escape(x) }.join( '|' ) )

        template.gsub!( re, map )
        template = self.expand_tags( dashboard: template, additional_tags: @additional_tags ) if( @additional_tags.count > 0 )

        # now we must recreate *all* panel IDs for an propper import
        template = JSON.parse( template )

        regenerate_template_ids( template )
      end

    end


    module Annotations

      # add standard annotations to all Templates
      #
      #
      def add_annotations(template_json )

        # add or overwrite annotations
        annotations = '
          {
            "list": [
              {
                "name": "created",
                "enable": false,
                "iconColor": "rgb(93, 227, 12)",
                "datasource": "events",
                "tags": "%STORAGE_IDENTIFIER% created&set=intersection"
              },
              {
                "name": "destoyed",
                "enable": false,
                "iconColor": "rgb(227, 57, 12)",
                "datasource": "events",
                "tags": "%STORAGE_IDENTIFIER% destroyed&set=intersection"
              },
              {
                "name": "Load Tests",
                "enable": false,
                "iconColor": "rgb(26, 196, 220)",
                "datasource": "events",
                "tags": "%STORAGE_IDENTIFIER% loadtest&set=intersection"
              },
              {
                "name": "Deployments",
                "enable": false,
                "iconColor": "rgb(176, 40, 253)",
                "datasource": "events",
                "tags": "%STORAGE_IDENTIFIER% deployment&set=intersection"
              }
            ]
          }
        '

        if( template_json.is_a?( String ) )
          template_json = JSON.parse( template_json )
        end

        annotation = template_json.dig( 'dashboard', 'annotations' )

        if( annotation != nil )
          template_json['dashboard']['annotations'] = JSON.parse( annotations )
        end

        template_json

      end

    end

  end
end

