
require 'yaml'
require 'erb'

class CMGrafana < Grafana::Client

  module ServerConfiguration

    public

    def read_config_file( params )

      raise ArgumentError.new(format('only Hash are allowed (%s given)', params.class.to_s )) unless( params.is_a?(Hash) )
      raise ArgumentError.new('missing settings') if( params.size.zero? )

      logger.debug( "read_config_file( #{params} )" )

      config_file = params.dig(:config_file)
      config_file = File.expand_path( config_file )
      config = nil

#       result = []

      if( !config_file.nil? && File.file?(config_file) )

        begin
          template = ERB.new File.new(config_file).read
          config   = YAML.load( template.result(binding) )
        rescue Exception => e
          puts( 'wrong result (no yaml)')
          puts(e)
          raise( 'no valid yaml File' )
        end
      else
        puts sprintf( 'Config File %s not found!', config_file )
        logger.error( sprintf( 'Config File %s not found!', config_file ) )
      end

      config
    end

    def configure_server( params )

      logger.debug( "configure_server( #{params} )" )

      config_file = params.dig(:config_file)
      config_file = File.expand_path( config_file )
      config = read_config_file( params )

      result = []

      unless( config.nil? )

        logger.info( format( 'configure server \'%s\'', @url ) )

        organisation = config.select { |x| x == 'organisation' }.values
        users        = config.select { |x| x == 'users' }
        datasources  = config.select { |x| x == 'datasources' }
        dashboards   = config.select { |x| x == 'dashboards' }.values
        admin_user   = config.select { |x| x == 'admin_user' }.values

        raise ArgumentError.new('organisation must be an Array') unless( organisation.is_a?(Array) )
        raise ArgumentError.new('users must be an Hash') unless( users.is_a?(Hash) )
        raise ArgumentError.new('datasources must be an Hash') unless( datasources.is_a?(Hash) )
        raise ArgumentError.new('dashboards must be an Array') unless( organisation.is_a?(Array) )
        raise ArgumentError.new('admin_user must be an Array') unless( organisation.is_a?(Array) )

        # TODO
        # read default organisation

  #     if( @logged_in == true )
  #       logger.debug( JSON.pretty_generate( admin_settings ) )
  #       logger.debug( JSON.pretty_generate( admin_stats ) )
  #     end

        result << grafana_organisation( organisation )
        result << grafana_users( users )
        result << grafana_datasources( datasources )
        result << grafana_dashboards( dashboards )
        result << grafana_admin_user( admin_user )
      end

      result
    end


    def grafana_organisation( params  )

      if( params.count >= 1 )

        params = params.first if( params.is_a?(Array) )

        @org_name = params.dig('name')

        if( @org_name.nil? )
          logger.error( 'missing org name' )
          return
        end

        logger.info( format( 'set organisation to \'%s\'', @org_name ) )

        org_by_name = organization_by_name( @org_name )

        status = org_by_name.dig('status') || 500

        if( status == 500 )

          logger.error( 'internal server error' )

        elsif( status == 404 )

          # org not exists
          logger.debug( 'create org' )

          org_created = create_organisation(
            name: @org_name
          )

          logger.debug( org_created )

        elsif( status == 200 )
          # org already exists
          # puts 'check'

          # update_organization
        end
      end


    end


    def grafana_users( params )

      if( params.count >= 1 )

        result = []

        users = params.dig('users')

        if( users.nil? )
          logger.error( 'missing username' )
          return
        end

        users.each do |u|

          user_name     = u.dig('username')
          login_name    = u.dig('login_name')
          email         = u.dig('email')
          password      = u.dig('password')
          grafana_admin = u.dig('grafana_admin') || false

          login_name    = user_name if( login_name.nil? )
          email         = format( '%s@domain.tld', user_name ) if( email.nil? || email.empty? )
          # grafana_admin = false if( grafana_admin.nil? )

          logger.debug( format('user: %s', user_name ) )

          next if( user_name.nil? )

          if( password.nil? )
            logger.error( format( 'no password for user %s given', user_name ) )
            next
          end

          usr_created = user_by_name( user_name )

          status = usr_created.dig('status') || 500

          if( status == 500 )

              logger.error( 'internal server error' )

          elsif( status == 404 )

            # user not exists
            logger.info( format('create user: %s', user_name ) )

            organisations = u.dig('organisations')

            config = {
              name: user_name,
              email: email,
              login: login_name,
              password: password
            }

            logger.debug( config )

            ## Global Users
            result << add_user( config )

            if( organisations.nil? )

              # add to default Organisation
              logger.info( format( '  - add user to organisation \'%s\' as \'%s\'', @org_name, 'Viewer'  ) )
  #            logger.debug( "add to Organisation '#{@org_name}' as Viewer" )

              ## Add User in Organisation
              add_user_to_organization(
                organization: @org_name,
                loginOrEmail: user_name,
                role: 'Viewer'
              )

            else

              if( organisations.is_a?(Array) )

                organisations.each do |o|

                  role   = 'Viewer'
                  org    = o.keys.first
                  values = o.values.first
                  # values = values.first if( values.is_a?(Array) )

                  unless( values.nil? )
                    role = o.values.first unless( o.values.nil? )
                    role = role.dig('role') unless( role.nil? )
                  end

                  logger.info( format( '  - add user to organisation \'%s\' as \'%s\'', org, role  ) )

                  ## Add User in Organisation
                  add_user_to_organization(
                    organization: org,
                    loginOrEmail: user_name,
                    role: role
                  )
                end

              end
            end

          elsif( status == 200 )

            # user exists
            logger.info( 'user exists' )
            logger.debug( 'check updates ...' )

            #role = u.dig('role')
            #usr_created_role.dig('isGrafanaAdmin')

            #if( u.role )

          end

          if(grafana_admin)

            logger.info( '  - set as grafana admin' )
            result << update_user_permissions( name: user_name, permissions: { grafana_admin: true } )
          end

        end

        result
      end

    end


    def grafana_datasources( params )

      if( params.count >= 1 )

        datasources = params.dig('datasources')

        if( datasources.nil? )
          logger.error( 'missing datasource' )
          return
        end

        ds_white_list = %w[influxdb graphite]

        datasources.each do |k,ds|

          defaults = ds.select { |x| x['default']}

          if( defaults.count > 1 )
            logger.error( format( 'only one default datasource for type %s allowed', k ) )
            next
          end

          type = k

          # whitelist for datasourcetypes
          unless( ds_white_list.include?(type) )
            logger.error( format( 'wrong type of datasource \'%s\'', type ) )
            next
          end

          next if( ds.nil? )

          ds.each do |v|

            name        = v.dig('name')
            host        = v.dig('host')
            port        = v.dig('port')
            database    = v.dig('database')
            default     = v.dig('default')
            ba_user     = v.dig('basic_auth', 'user')
            ba_password = v.dig('basic_auth', 'password')
            data        = v.dig('data')

            next if( name.nil? )

            if( port.nil? )

              port = 8080 if( type == 'graphite' )
              port = 8080 if( type == 'influxdb' )
            end

            logger.debug( format('datasource: %s :: %s', type, name ) )

            data_src = data_source( name )
            status = data_src.dig('status') || 500

            if( status == 500 )

              logger.error( 'internal server error' )

            elsif( status == 404 )

              # user not exists
              logger.info( format('create datasource: %s :: %s', type, name ) )

              config = {
                'name' => name,
                'database' => database,
                'type' => type,
                'access' => 'proxy',
                'url' => format('http://%s:%d', host, port),
                'jsonData' => data.deep_symbolize_keys,
                'default' => default
              }

              config['basic_auth_user'] = ba_user unless(ba_user.nil?)
              config['basic_auth_password'] = ba_password unless(ba_password.nil?)

              config = config.deep_symbolize_keys

              create_datasource( config )

            elsif( status == 200 )

              # user exists
              logger.info( format( 'datasource %s :: %s exists', type, name ) )
              # logger.debug( 'check updates ...' )

              config = {
                'name' => name,
                'database' => database,
                'type' => type,
                'access' => 'proxy',
                'url' => format('http://%s:%d', host, port),
                'jsonData' => data.deep_symbolize_keys,
                'default' => default
              }

              config['basic_auth_user'] = ba_user unless(ba_user.nil?)
              config['basic_auth_password'] = ba_password unless(ba_password.nil?)

              config = config.deep_symbolize_keys

              result = update_datasource( datasource: name, data: config )

              logger.debug( result )

            end

          end

        end
      end
    end


    def grafana_dashboards( params )

      if( params.count >= 1 )

        params = params.first if( params.is_a?(Array) )

        import_from = params.dig('import_from_directory')

        return if( import_from.nil?)

        logger.info( format( 'import dashboards from directory %s', import_from ) )

        import_dashboards_from_directory( import_from )
      end

    end


    def grafana_admin_user( params )

      if( params.count >= 1 )

        params = params.first if( params.is_a?(Array) )

        admin_username   = params.dig('username')
        admin_password   = params.dig('password')
        admin_login_name = params.dig('login_name')
        admin_email      = params.dig('email')
        admin_theme      = params.dig('theme') || ''
        result = []

        theme_white_list = %w[dark light]

        unless( admin_theme.nil? || admin_theme.empty? )

          unless( theme_white_list.include?(admin_theme) )
            logger.error( format( 'wrong theme \'%s\'', admin_theme ) )
            logger.debug( 'remove theme' )

            params.delete('theme')
          end
        end

        adm_user = user_by_name(@user)

        # admin: adm_user.dig('isGrafanaAdmin')
        left = {
          email: adm_user.dig('email'),
          name: adm_user.dig('name'),
          login: adm_user.dig('login'),
          theme: adm_user.dig('theme')
        }

        right = {
          email: admin_email,
          name: admin_username,
          login: admin_login_name,
          theme: admin_theme
        }

        if( left.sort != right.sort )

          logger.info( 'update admin user' )
          logger.debug( left.sort )
          logger.debug( right.sort )

          user_data = {}

          user_data[:user_name]  = @user
          user_data['name']  = admin_username unless( admin_username.nil? )
          user_data['login'] = admin_login_name unless( admin_login_name.nil? )
          user_data['email'] = admin_email unless( admin_email.nil? )
          user_data['theme'] = admin_theme unless( admin_theme.nil? )

          result << update_user( user_data )
        end

        unless( admin_password.nil? )

          logger.info( 'update admin password' )

          result << update_user_password(
            user_name: admin_login_name,
            password: admin_password
          )
        end

        result
      end
    end

  end

end
