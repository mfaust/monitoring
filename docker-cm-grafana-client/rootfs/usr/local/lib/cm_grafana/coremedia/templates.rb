
class CMGrafana

  module CoreMedia

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

                ip, short, fqdn = self.ns_lookup(mls)

                dns = @database.dnsData( ip: ip, short: short, fqdn: fqdn )

                if( dns.nil? )
                  logger.warn(format('no DNS Entry for the Master Live Server \'%s\' found!', mls))
                else

                  real_ip    = dns.dig('ip')
                  real_short = dns.dig('name')
                  real_fqdn  = dns.dig('fqdn')

                  if( @short_hostname != real_short )

                    identifier  = @database.config( ip: real_ip, short: real_short, fqdn: real_fqdn, key: 'graphite_identifier' )

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
        template = JSON.parse( template ) if( template.is_a?( String ) )
        template = expand_tags( dashboard: template, additional_tags: @additional_tags ) if( @additional_tags.count > 0 )

        # now we must recreate *all* panel IDs for an propper import
        template = JSON.parse( template ) if( template.is_a?( String ) )

        regenerate_template_ids( template )
      end

    end

  end
end

