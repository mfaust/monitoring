
require 'yaml'


  public
  def configure_server( params )

    config_file = params.dig(:config_file)
    config_file = File.expand_path( config_file )
    config = nil

    result = []

    if( !config_file.nil? && File.file?(config_file) )

      begin

        config = YAML.load_file( config_file )

      rescue Exception

        logger.error( 'wrong result (no yaml)')
        logger.error( "#{$!}" )

        raise( 'no valid yaml File' )
        exit 1
      end
    else
      logger.error( sprintf( 'Config File %s not found!', config_file ) )
    end



    unless( config.nil? )

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

      logger.debug( admin_user )

      # TODO
      # read default organisation

#       result << grafana_organisation( organisation )
#       result << grafana_users( users )
#       result << grafana_datasources( datasources )
#       result << grafana_dashboards( dashboards )
      result << grafana_admin_user( admin_user )
    end

    result
  end


  def grafana_organisation( params  )

    if( params.count >= 1 )

      params = params.first if( params.is_a?(Array) )

#       puts params
#       puts params.class.to_s
#       puts JSON.pretty_generate(params)

      @org_name = params.dig('name')

      if( @org_name.nil? )
        logger.error( 'missing org name' )
        return
      end

      org_by_name = organization_by_name( @org_name )

      status = org_by_name.dig('status')

      if( status == 404 )

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

      users = params.dig('users')

      if( users.nil? )
        logger.error( 'missing username' )
        return
      end

      users.each do |u|

        login_name = u.dig('login_name')
        user_name = u.dig('username')
        email = u.dig('email')
        password = u.dig('password')

        logger.debug( format('user: %s', user_name ) )

        next if( user_name.nil? )

        if( password.nil? )
          logger.error( format( 'no password for user %s given', user_name ) )
          next
        end

        usr_created = user_by_name( user_name )

        status = usr_created.dig('status')

        if( status == 404 )

          # user not exists
          logger.debug( 'create user' )

          organisations = u.dig('organisations')

          ## Global Users
          #add_user(
          #  user_name: '',
          #  email: '',
          #  login_name: '',
          #  password: ''
          #)

          if( organisations.nil? )

            # add to default Organisation
            logger.debug( "add to Organisation '#{@org_name}' as Viewer" )

            ## Add User in Organisation
            #add_user_to_organization(
            #  organization: '',
            #  loginOrEmail: '',
            #  role: 'Viewer'
            #)

          else

            if( organisations.is_a?(Array) )

              organisations.each do |o|

                org    = o.keys.first
                values = o.values.first
                # values = values.first if( values.is_a?(Array) )

                if( values.nil? )
                  role = 'Viewer'
                else
                  role = o.values.first unless( o.values.nil? )
                  role = role.dig('role') unless( role.nil? )
                end

                logger.debug( "add to Organisation '#{org}' as #{role}" )

                ## Add User in Organisation
                #add_user_to_organization(
                #  organization: '',
                #  loginOrEmail: '',
                #  role: ''
                #)
              end

            end
          end

        elsif( status == 200 )

          # user exists
          logger.debug( 'user exists' )
          logger.debug( 'check updates ...' )

          #role = u.dig('role')
          #usr_created_role.dig('isGrafanaAdmin')

          #if( u.role )

        end

      end

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

        defaults = ds.select { |x| x['default'] == true }

        if( defaults.count > 1 )
          logger.error( format( 'only one default datasource for type %s allowed', k ) )
          next
        end

        ds.each do |v|

          type = k

          unless( ds_white_list.include?(type) )
            logger.error( format( 'wrong type of datasource \'%s\'', type ) )
            next
          end

          # TODO
          # whitelist for datasourcetypes

          name = v.dig('name')
          host = v.dig('host')
          port = v.dig('port')
          database = v.dig('database')
          default = v.dig('default')
          ba_user = v.dig('basic_auth', 'user')
          ba_password = v.dig('basic_auth', 'password')
          data = v.dig('data')

          logger.debug( format('datasource: %s :: %s', type, name ) )

          next if( name.nil? )

          logger.debug( format( 'check datasource %s', name ) )

          data_src = data_source( name )

          status = data_src.dig('status')

          if( status == 404 )

            # user not exists
            logger.debug( 'create datasource' )

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
            logger.debug( 'datasource exists' )
            logger.debug( 'check updates ...' )

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
      admin_theme      = params.dig('theme')

      theme_white_list = %w[dark light]

      unless( theme_white_list.include?(admin_theme) )
        logger.error( format( 'wrong theme \'%s\'', admin_theme ) )
        logger.debug( 'remove theme' )

        params.delete('theme')
      end

      adm_user = user_by_name(@user)

# logger.debug( adm_user )

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

#       logger.debug( left.sort )
#       logger.debug( right.sort )

      if( left.sort != right.sort )

        puts 'need update'
        user_data = {}

        user_data[:user_name]  = @user
        user_data['name']  = admin_username unless( admin_username.nil? )
        user_data['login'] = admin_login_name unless( admin_login_name.nil? )
        user_data['email'] = admin_email unless( admin_email.nil? )
        user_data['theme'] = admin_theme unless( admin_theme.nil? )

#         logger.debug( user_data )
        result = update_user( user_data )

        logger.debug( result )
      end

      unless( admin_password.nil? )

        result = update_user_password(
          user_name: admin_login_name,
          password: admin_password
        )

        logger.debug( result )

      end

    end
  end
