
class CMGrafana

  module CoreMedia

    module Dashboard


      def prepare(host)

        # get a DNS record
        #
        ip, short, fqdn = ns_lookup(host)

        @short_hostname      = short  # (%HOST%)
        @slug                = short  # name for the grafana title (%SHORTNAME%)
        @graphite_identifier = fqdn   # identifier for an storage path (<%= graphite_identifier %>) (useful for cloud stack on aws with changing hostnames)

        # read the configuration for an customized display name
        #
        display     = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'display_name' )
        identifier  = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'graphite_identifier' )

        if( display != nil && display.dig( 'display_name' ) != nil )
          @slug = display.dig( 'display_name' ).to_s
          logger.info( "use custom display_name from config: '#{@slug}'" )
        end

        if( identifier != nil && identifier.dig( 'graphite_identifier' ) != nil )
          @graphite_identifier = identifier.dig( 'graphite_identifier' ).to_s
          logger.info( "use custom storage identifier from config: '#{@graphite_identifier}'" )
        end

        @slug  = slug( @slug ).gsub( '.', '-' )

        @dashboard_uuid  = @slug.gsub(/-\w{1,2}-\d{1,2}-(.*)-tomcat-/, '-')
        @folder_uuid     = @slug.scan(/(\w+-\w{1,2}-\d{1,2}-.*)-tomcat(-\d{1,2})-.*/).last
        if(@folder_uuid.nil?)
          @folder_uuid   = @slug
        else
          @folder_uuid   = @folder_uuid.join
        end

        logger.debug( format('ip   : %s', ip))
        logger.debug( format('short: %s', short))
        logger.debug( format('fqdn : %s', fqdn))
        logger.debug( "short hostname     : #{@short_hostname}" )
        logger.debug( "slug               : #{@slug}" )
        logger.debug( "dashboard uuid     : #{@dashboard_uuid}" )
        logger.debug( "folder uuid        : #{@folder_uuid}" )
        logger.debug( "graphite identifier: #{@graphite_identifier}" )

        [ ip, short, fqdn ]
      end

      # creates an Grafana Dashboard for CoreMedia Services
      # the Dashboard will be create from pre defined Templates
      #
      # @param [Hash, #read] params the params for parameters
      # @option params [String] :host Filter for Hostname
      # @option params [String] :tags additional Tags
      # @option params [Bool] :overview create an Overview Dashboard
      #
      #
      def create_dashboard_for_host(params)

        logger.debug("create_dashboard_for_host(#{params})")

        host                = params.dig(:host)
        @additional_tags    = params.dig(:tags)     || []
        create_overview     = params.dig(:overview) || false
        overview_grouped_by = params.dig(:overview_grouped_by) || []

        if( host.nil? )
          logger.error( 'missing hostname to create Dashboards' )
          return { status: 500, message: 'missing hostname to create Dashboards' }
        end

        start = Time.now

        logger.info( format( 'Adding dashboards for host \'%s\'', host ) )

        ip, short, fqdn = self.prepare( host )

        discovery = discovery_data( ip: ip, short: short, fqdn: fqdn )

        return { status: 400, message: 'no discovery data found' } if( discovery.nil? )

        services       = discovery.keys
        logger.debug( "Found services: #{services}" )

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
            return { status: 404, message: format( 'Maximum retries (%d) against \'%s/login\' reached. Giving up ...', login_max_retried, @url ) }
#            raise format( 'Maximum retries (%d) against \'%s/login\' reached. Giving up ...', login_max_retried, @url )
          end
        end

        # create folder for every host
        create_host_folder(@folder_uuid)

        # create service dashboards
        #
        service_dasboard_result = create_service_dashboard( dns: { ip: ip, short: short, fqdn: fqdn }, discovery: discovery )

        # create license dashboard
        #
        #create_license_dashboard_OBSOLETE( dns: { ip: ip, short: short, fqdn: fqdn }, services: services )
        create_license_dashboard( dns: { ip: ip, short: short, fqdn: fqdn }, services: services )

        # we want an Services Overview for this Host
        #
        create_overview_dashboard(services, service_dasboard_result) if(create_overview) # add description

        dashboards = list_dashboards( tags: short )
        dashboards = dashboards.dig(:dashboards)

        # TODO
        # clearer!
        return { status: 404, message: 'no dashboards added' } if( dashboards.nil? )

        count      = dashboards.count

        if( count.to_i != 0 )
          status  = 200
          message = format( '%d dashboards added', count )
        else
          status  = 404
          message = 'Error for adding Dashboads'
        end

        finish = Time.now
        logger.info( format( 'finished in %s seconds', (finish - start).round(2) ) )

        { status: status, name: host, message: message  }
      end

      # create the overview dashboads
      #
      # @param [Array, #read] services an array with all known services
      #
      def create_overview_dashboard(services, service_dashboard_data)

        logger.info( 'create Overview dashboard' )

        slug                = @slug
        uuid                = format( '%s-overview', @dashboard_uuid )
        graphite_identifier = @graphite_identifier
        short_hostname      = @short_hostname

        logger.debug("services: #{services}")
        logger.debug("service_dashboard_data: #{service_dashboard_data}")

        # ---------------------------------------------------------

        template = "#{@template_directory}/overview.erb"

        if( File.exist?( template ) )
          template = File.read( template )
          renderer = ERB.new( template, nil, '-' )
          content = renderer.result(binding)

          content = JSON.parse(content) if(content.is_a?(String))
          content = regenerate_template_ids( content )

          content = JSON.parse( content ) if( content.is_a?(String) )
          title = content.dig('dashboard','title')

          logger.debug("title: #{title}")

          response = create_dashboard( title: title, dashboard: content, folderId: @folder_uuid )
          response_status  = response.dig('status').to_i
          response_message = response.dig('message')

          logger.debug("response: #{response}")

          logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
        end
      end


      def create_license_dashboard(params = {})

        logger.info( 'create License Dashboard' )

        fqdn            = params.dig(:dns, :fqdn)
        short           = params.dig(:dns, :short)
        services        = params.dig(:services) || []
        content_servers = %w(content-management-server master-live-server replication-live-server)

        logger.debug("services: #{services}")

        begin
          (1..30).each { |y|
            if( @redis.measurements( short: short, fqdn: fqdn ).nil? )
              logger.debug(format('wait for measurements data for node \'%s\' ... %d', short, y))
              sleep(4)
            else
              break
            end
          }
        rescue => e
          logger.error( e )
        end

        return { status: 204, message: 'no content-server available' } unless( services.sort.any? {|x| content_servers.sort.include?(x) } )

        intersect       = content_servers & services

        logger.debug("intersect: #{intersect}")

        content_srv_data = {}

        intersect.each do |service|
          logger.debug( format( 'Search License Information for Service %s', service ) )

          begin
            (1..30).each { |y|

              r = @mbean.beanAvailable?( fqdn, service, 'Server', 'LicenseValidUntilHard')

              logger.debug(r)

              if( r.nil? )
                logger.debug(format('wait for measurements data for service \'%s\' ... %d', service, y))
                sleep(4)
              else
                break
              end
            }
          rescue => e
            logger.error( e )
          end

          if( @mbean.beanAvailable?( fqdn, service, 'Server', 'LicenseValidUntilHard') )

            logger.info( format( '  - found License Information for Service %s', service ) )
            content_srv_data[service] = {}
            content_srv_data[service]['normalized_name'] = normalize_service(service)
          end

          logger.debug( format( 'Search Service Information for Service %s', service ) )

          if( @mbean.beanAvailable?( fqdn, service, 'Server', 'ServiceInfos') )
            logger.info( format( '  - found Service Information for Service %s', service ) )

            content_srv_data[service]['service_info'] = 'publisher'
            content_srv_data[service]['service_info_title'] = 'Publisher'
            content_srv_data[service]['service_info'] = 'webserver' if( service == 'replication-live-server' )
            content_srv_data[service]['service_info_title'] = 'Webserver' if( service == 'replication-live-server' )

          end

        end

        slug                = @slug
        uuid                = format( '%s-licenses', @dashboard_uuid )
        graphite_identifier = @graphite_identifier
        short_hostname      = @short_hostname

        logger.debug(content_srv_data)

        template = "#{@template_directory}/licenses.erb"

        if( File.exist?( template ) )

          template = File.read( template )
          renderer = ERB.new( template, nil, '-' )
          content = renderer.result(binding)

          content = JSON.parse(content) if(content.is_a?(String))

          content = regenerate_template_ids( content )


          content = JSON.parse( content ) if( content.is_a?(String) )
          title = content.dig('dashboard','title')

          response = create_dashboard( title: title, dashboard: content, folderId: @folder_uuid )
          response_status  = response.dig('status').to_i
          response_message = response.dig('message')

          logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
        end
      end


      # creates a license dashboard if the information is available
      #
      # @param [Hash, #read] params
      # @option params [Hash, #read] dns
      # @option params [Array, #read] services
      #
      def create_license_dashboard_OBSOLETE(params = {})

        logger.info( 'create License Dashboard' )

        fqdn            = params.dig(:dns, :fqdn)
        short           = params.dig(:dns, :short)
        services        = params.dig(:services) || []
        content_servers = %w(content-management-server master-live-server replication-live-server)

        begin
          (1..30).each { |y|
            if( @redis.measurements( short: short, fqdn: fqdn ).nil? )
              logger.debug(format('wait for measurements data for node \'%s\' ... %d', short, y))
              sleep(4)
            else
              break
            end
          }
        rescue => e
          logger.error( e )
        end

        return { status: 204, message: 'no content-server available' } unless( services.sort.any? {|x| content_servers.sort.include?(x) } )

        rows            = []
        intersect       = content_servers & services

        # license_template = format( '%s/licenses/licenses-template.erb' , @template_directory )
        license_head     = format( '%s/licenses/licenses-head.erb' , @template_directory )
        license_until    = format( '%s/licenses/licenses-until.erb', @template_directory )
        license_part     = format( '%s/licenses/licenses-part.erb' , @template_directory )

        intersect.each do |service|
          logger.debug( format( 'Search License Information for Service %s', service ) )
          if( @mbean.beanAvailable?( fqdn, service, 'Server', 'LicenseValidUntilHard') )
            logger.info( format( '  - found License Information for Service %s', service ) )

            rows << File.read(license_until).gsub!( '<%= normalized_name %>', normalize_service(service) ) if( File.exist?(license_until) )
          end
        end

        rows << File.read( license_head )  if( File.exist?( license_head ) )

        intersect.each do |service|
          logger.debug( format( 'Search Service Information for Service %s', service ) )
          if( @mbean.beanAvailable?( fqdn, service, 'Server', 'ServiceInfos') )
            logger.info( format( '  - found Service Information for Service %s', service ) )
            if( File.exist?( license_part ) )
              tpl = File.read( license_part )
              tpl.gsub!( '<%= normalized_name %>', normalize_service(service) )
              tpl.gsub!( 'Server.ServiceInfo.publisher' , 'Server.ServiceInfo.webserver' ).gsub!( 'Publisher', 'Webserver' ) if( service == 'replication-live-server' )

              rows << tpl
            end
          end
        end

        # only the license Head is into the array
        #
        return { status: 204, message: 'we have no information about licenses' } if( rows.count == 1 )

        rows = rows.join(',')

        template = %(
          {
            "dashboard": {
              "id": null,
              "uid": "<%= uuid %>",
              "title": "<%= slug %> - Licenses",
              "originalTitle": "<%= slug %> - Licenses",
              "tags": [ "<%= short_hostname %>", "licenses" ],
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
                      "value": "<%= graphite_identifier %>",
                      "text": "<%= graphite_identifier %>"
                    },
                    "hide": 2,
                    "label": null,
                    "name": "host",
                    "options": [
                      {
                        "value": "<%= graphite_identifier %>",
                        "text": "<%= graphite_identifier %>"
                      }
                    ],
                    "query": "<%= graphite_identifier %>",
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

        json = normalize_template(
          template: template,
          service_name: 'licenses',
          slug: @slug,
          graphite_identifier: @graphite_identifier,
          short_hostname: @short_hostname
        )

        json = JSON.parse( json ) if( json.is_a?(String) )
        title = json.dig('dashboard','title')

        response = create_dashboard( title: title, dashboard: json )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )
      end


      # creates service dashboards
      #
      # @param [Hash, #read] params
      # @option params [Hash, #read] dns
      # @option params [Hash, #read] discovery
      #
      def create_service_dashboard(params = {})

        logger.info( 'add service dashboards' )

        fqdn       = params.dig(:dns, :fqdn)
        short      = params.dig(:dns, :short)
        discovery  = params.dig(:discovery)
        services   = discovery.keys

        discovery.delete( 'mysql' )
        discovery.delete( 'postgres' )
        discovery.delete( 'mongodb' )
        discovery.delete( 'demodata-generator' )
        discovery.delete( 'http-proxy' )
        discovery.delete( 'https-proxy' )
        discovery.delete( 'node-exporter' )

#         logger.debug( " - discovery: #{discovery}" )
#         logger.debug( " - services : #{services}" )

        service_dashboards_result = {}

        # named Templates are a subset of specialized Templates
        # like Memory-Pools, Tomcat or simple Grafana-Templates
        named_template_array = []

        # MemoryPools for many Services
        #
        named_template_array.push( 'memory-pool' )

        # unique Tomcat Dashboard
        #
        named_template_array.push( 'tomcat' )

        # CAE Caches
        #
        if( services.include?( 'cae-preview' ) || services.include?( 'cae-live' ) )
          named_template_array.push( 'cae-cache-classes' )
          named_template_array.push( 'cae-cache-classes-ecommerce' ) if(@mbean.beanAvailable?( fqdn, 'cae-preview', 'CacheClassesECommerceAvailability'))
        end

        # add Operation Datas for NodeExporter
        #
        if( services.include?('node-exporter') )
          named_template_array.push( 'node-exporter' )
          service_dashboards_result['node-exporter'] = { 'normalized_name' => 'NODE_EXPORTER' }
        end

        # add HTTP dashboard
        #
        if( services.include?('http-status') )
          named_template_array.push( 'http-status' )
          service_dashboards_result['http-status'] = { 'normalized_name' => 'HTTP_STATUS' }
        end

        # add mysql dashboad
        #
        if( services.include?('mysql') )
          named_template_array.push( 'mysql' )
          service_dashboards_result['mysql'] = { 'normalized_name' => 'MYSQL' }
        end

        # add mongodb dashboad
        #
        if( services.include?('mongodb') )
          named_template_array.push( 'mongodb' )
          service_dashboards_result['mongodb'] = { 'normalized_name' => 'MONGODB' }
        end

        # since grafana 5, all dashboards has an UUID for linkbuilding
        # we need also the real link to our tomcat dashboard

        tomcat_dashboard_url = dashboad_url('tomcats')
        memorypools_dashboard_url = dashboad_url('memory-pools')

        # add named templates for static templates
        #
        named_template_array.each do |template|

          logger.debug( format( '  search template for: \'%s\'', template ) )

          filename = template_for_service(template)

          next if( filename.nil? )

          next unless( File.exist?( filename ) )

          logger.debug( format( '  use template file: \'%s\'', File.basename( filename ).strip ) )
#           logger.debug("service_dashboards_result: #{service_dashboards_result}")

          unless( template.to_s.empty? )
            r = create_service_template(
              service_name: template,
              normalized_name: normalize_service(template),
              service_template: filename,
              tomcat_dashboard_url: tomcat_dashboard_url,
              memorypools_dashboard_url: memorypools_dashboard_url
            )

          end
        end

        discovery.each do |service,service_data|

          additional_template_paths = []
          description    = nil
          template       = nil

          unless( service_data.nil? )
            description    = service_data.dig( 'description' )
            template       = service_data.dig( 'template' )
          end

          # cae-live-1 -> cae-live
          service_name     = remove_postfix( service )
          normalized_name  = normalize_service( service )
          template_name    = template != nil ? template : service_name
          service_template = template_for_service( template_name )

          # logger.debug( format( '  service_name  %s', service_name ) )
          # logger.debug( format( '  description   %s', description ) )
          # logger.debug( format( '  template      %s', template ) )
          # logger.debug( format( '  template_name %s', template_name ) )
          # logger.debug( format( '  template file %s', service_template ) )

          # FIX
          # 2018-02-16
          # we have an own tomcat dashboard
          #
          # additional_template_paths << template_for_service( 'tomcat' ) unless( %w(mongodb mysql postgres node-exporter http-status http-proxy https-proxy).include?( service_name ) )

          unless( service_template.to_s.empty? )
            r = create_service_template(
              description: description,
              service_name: service_name,
              normalized_name: normalized_name,
              service_template: service_template,
              tomcat_dashboard_url: tomcat_dashboard_url,
              memorypools_dashboard_url: memorypools_dashboard_url,
              additional_template_paths: additional_template_paths
            )

            r = r.dig(:message)
            r = JSON.parse(r) if(r.is_a?(String))
            r['normalized_name'] = normalized_name

            service_dashboards_result[service_name] ||= r
          end
        end

        service_dashboards_result
      end


      # List Grafana Dashboards
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
          # d.gsub!( format( 'db/%s-', tags ), '' )
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

          logger.info( format( 'remove %d dashboards for host %s (%s)', count, host, @slug ) )
#           logger.debug( format( 'found %d dashboards for delete', count ) )

          # ensure, that we are logged in
          login( username: @user, password: @password, max_retries: 10 )

          dashboards.each do |d|

            # TODO
            #if( (i.include?"group") && ( !host.include?"group") )
            #  # Don't delete group templates except if deletion is forced
            #  next
            #end

            logger.debug( format( '  - %s :: %s', host, d ) )

            response = delete_dashboard( d )

            logger.debug( response )

            status = response.dig('status')

            delete_count += 1 if( status == 200 )

          end

          logger.info( format( '%d dashboards deleted', delete_count ) )

          delete_host_folder(@folder_uuid)

          return { status: 200, name: host, message: format( '%d dashboards deleted', delete_count ) }
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

        unless(overview_dashboard.nil?)

          logger.debug( "overview_dashboard: #{overview_dashboard}" )

          logger.debug( 'first, delete combined dashboards: overview and licenses' )
          overview_dashboard.each do |d|
            logger.debug( format( '  - %s :: %s', host, d ) )
            response = delete_dashboard( d )
            # logger.debug( response )
            status = response.dig('status')
          end

          unless(licenses_dashboard.nil? )

            licenses_dashboard.each do |d|
              logger.debug( format( '  - %s :: %s', host, d ) )
              response = delete_dashboard( d )
              # logger.debug( response )
              status = response.dig('status')
            end
          end
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

        # we need <%= slug %> and <%= graphite_identifier %> for every host
        servers.each do |s|

          logger.debug( "host: #{s}" )

          ip, short, fqdn     = self.ns_lookup(s)
          short_hostname      = short  # (%HOST%)
          slug                = fqdn   # name for the grafana title (%SHORTNAME%)
          graphite_identifier = fqdn   # identifier for an storage path (<%= graphite_identifier %>) (useful for cloud stack on aws with changing hostnames)

          # read the configuration for an customized display name
          #
          display     = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'display_name' )
          identifier  = @database.config( ip: ip, short: short, fqdn: fqdn, key: 'graphite_identifier' )

          if( identifier != nil && identifier.dig( 'graphite_identifier' ) != nil )
            graphite_identifier = identifier.dig( 'graphite_identifier' ).to_s
            logger.info( "use custom storage identifier from config: '#{graphite_identifier}'" )
          end

          if( display != nil && display.dig( 'display_name' ) != nil )
            slug = display.dig( 'display_name' ).to_s
            logger.info( "use custom display_name from config: '#{slug}'" )
          end

          rows << overview_host_header(s)

          discovery = discovery_data( fqdn: s )
          services  = discovery.keys
          logger.debug( "  Found services: #{services}" )

          rows << overview_template_rows(services)

          begin
            rows.gsub!('<%= slug %>', short_hostname)
            rows.gsub!('$host', slug)
          rescue =>error
            logger.error(error)
          end
        end

        rows            = rows.join(',')

        template = %(
          {
            "dashboard": {
              "id": null,
              "uid": null,
              "title": "= Overview",
              "originalTitle": "= Overview",
              "tags": [ "overview" ],
              "style": "dark",
              "timezone": "browser",
              "editable": true,
              "hideControls": true,
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

        response         = create_dashboard( dashboard: template, folderId: @folder_uuid )
        response_status  = response.dig('status').to_i
        response_message = response.dig('message')

        logger.warn( format('template can\'t be add: [%s] %s', response_status, response_message ) ) if( response_status != 200 )

        response
      end



      def dashboad_url(tag)

        data = search_dashboards( tags: [tag, @short_hostname ] )
        data = JSON.parse(data) if(data.is_a?(String))

        # "url"=>"/grafana/d/eZ01Vmqkk/osmc-local-memory-pools"
        data = data.dig('message') unless( data.nil? )
        url = data.first.dig('url') if(data.is_a?(Array) && data.count != 0 )
        # helpful for backward compatibility (grafana4)
        url = format('/grafana/dashboard/db/%s-%s', @slug, tag ) if( url.nil? )

        url
      end

    end
  end
end

