
class CMGrafana

  module CoreMedia

    module Dashboard


      def prepare(host)

        # get a DNS record
        #
        ip, short, fqdn = self.ns_lookup(host)

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
      def create_dashboard_for_host(params)

        host            = params.dig(:host)
        @additional_tags = params.dig(:tags)     || []
        create_overview  = params.dig(:overview) || false
        overview_grouped_by = params.dig(:overview_grouped_by) || []

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
        begin
          login_retried ||= 0
          login_max_retried ||= 4
          login_sleep_between_retries = 4
          login( username: @user, password: @password, max_retried: login_max_retried )
        rescue
          if( login_retried < login_max_retried )
            login_retried += 1
            logger.debug( format( 'cannot login, socket error (retry %d / %d)', login_retried, login_max_retried ) )
            sleep( login_sleep_between_retries )
            retry
          else
            raise format( 'Maximum retries (%d) against \'%s/login\' reached. Giving up ...', login_max_retried, @url )
          end
        end

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

        dashboards = list_dashboards( tags: short ) #@grafana_hostname } )
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

        rows = self.overview_template_rows(services)
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
        login( username: @user, password: @password, max_retries: 10 )

        data = search_dashboards( tags: tags )
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
          login( username: @user, password: @password, max_retries: 10 )

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

      # create overview for a list of servers
      #
      # @param [Array] params are a Array with servers (fqdn)
      #
      def create_overview_dashboard_for_hosts( servers, group_by_tags )

        return { status: 404, message: 'no servers for grouped overview dashboard' } unless( servers.is_a?(Array) || servers.count == 0 )

        rows = []
        templating_list = []

        # we need %SHORTHOST% and %STORAGE_IDENTIFIER% for every host

        servers.each do |s|

          logger.debug( "host: #{s}" )

          ip, short, fqdn = self.ns_lookup(s)
          short_hostname     = short  # (%HOST%)
          grafana_hostname   = fqdn   # name for the grafana title (%SHORTNAME%)
          storage_identifier = fqdn   # identifier for an storage path (%STORAGE_IDENTIFIER%) (useful for cloud stack on aws with changing hostnames)

          # read the configuration for an customized display name
          #
          display     = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'display_name' )
          identifier  = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'graphite_identifier' )

          if( identifier != nil && identifier.dig( 'graphite_identifier' ) != nil )
            storage_identifier = identifier.dig( 'graphite_identifier' ).to_s
            logger.info( "use custom storage identifier from config: '#{storage_identifier}'" )
          end

          if( display != nil && display.dig( 'display_name' ) != nil )
            grafana_hostname = display.dig( 'display_name' ).to_s
            logger.info( "use custom display_name from config: '#{grafana_hostname}'" )
          end

          # grafana_hostname  = slug( grafana_hostname ).gsub( '.', '-' )

#           # TODO
#           # we need here the STORAGE_IDENTIFIER
#           templating_list << %(
#             {
#               "current": { "value": "#{grafana_hostname}", "text": "#{grafana_hostname}" },
#               "hide": 2,
#               "label": null,
#               "name": "host",
#               "options": [ { "value": "#{grafana_hostname}", "text": "#{grafana_hostname}" } ],
#               "query": "#{grafana_hostname}",
#               "type": "constant"
#             }
#           )

#          rows << overview_host_header(s)

          discovery = discovery_data( fqdn: s )
          services  = discovery.keys
          logger.debug( "  Found services: #{services}" )

          rows << overview_template_rows(services)

          begin
            # rows = rows.map { |s| s.gsub('%SHORTHOST%', short_hostname).gsub('$host', grafana_hostname) }
            rows.gsub!('%SHORTHOST%', short_hostname)
            rows.gsub!('$host', grafana_hostname)
          rescue =>error
            logger.error(error)
          end

        end

#         logger.debug(rows)

        rows            = rows.join(',')
#         templating_list = templating_list.join(',')

        template = %(
          {
            "dashboard": {
              "id": null,
              "title": "= Overview",
              "originalTitle": "= Overview",
              "tags": [ "overview" ],
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

        template = JSON.parse( template ) if( template.is_a?( String ) )
        template = expand_tags( dashboard: template, additional_tags: group_by_tags ) if( group_by_tags.count > 0 )
        # now we must recreate *all* panel IDs for an propper import
        template = JSON.parse( template ) if( template.is_a?( String ) )
        template = regenerate_template_ids( template )
        template = JSON.parse( template ) if( template.is_a?(String) )

        title = template.dig('dashboard','title')

        logger.debug( JSON.pretty_generate( template ) )

        begin
        response = create_dashboard( dashboard: template )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')
        rescue => error
          logger.error error
        end

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
      end

    end

  end
end

