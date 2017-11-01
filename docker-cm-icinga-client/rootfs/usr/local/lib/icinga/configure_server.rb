
require 'yaml'

class CMIcinga2 < Icinga2::Client

  module ServerConfiguration

    public

    def read_config_file( params )

      logger.debug( "read_config_file( #{params} )" )

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
        end
      else
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

        logger.info( format( 'configure server \'%s\'', @icinga_host ) )

        groups       = config.select { |x| x == 'groups' }.values
        users        = config.select { |x| x == 'users' }.values

        raise ArgumentError.new(format( 'groups must be an Array, given an %s', groups.class.to_s ) ) unless( groups.is_a?(Array) )
        raise ArgumentError.new(format( 'users must be an Array, given an %s', users.class.to_s ) ) unless( users.is_a?(Array) )

        result << icinga_groups( groups )
        result << icinga_users( users )
      end

      logger.debug( JSON.pretty_generate( result ) )

      result
    end



    def icinga_groups( params )

      if( params.count >= 1 )

        result = []
        params.each do |p|

          p.each do |k,v|

            v = JSON.parse(v) if( v.is_a?(String) )

            group_name = k
            group_description = v.dig('description') || group_name

            unless( exists_usergroup?( group_name ) )

              logger.info( format('create group: %s (%s)', group_name, group_description ) )
              # create group
              result << add_usergroup( user_group: group_name, display_name: group_description )
            end

          end
        end

        result
      end
    end

    def icinga_users( params )

      if( params.count >= 1 )

        result = []

        logger.debug( JSON.pretty_generate( params ) )

        params.each do |p|

          p.each do |k,v|

            v = JSON.parse(v) if( v.is_a?(String) )

            user_name    = k
            display_name = v.dig('display_name') || user_name
            email        = v.dig('email')
            pager        = v.dig('pager')
            groups       = v.dig('groups') || []
            enable_notifications = v.dig('enable_notifications')

            enable_notifications = enable_notifications.to_s.eql?('true') ? true : false

            unless( exists_user?( user_name ) )

              logger.info( format('create user: %s (%s)', user_name, display_name ) )
              logger.info( format( '  - as group member for: %s', groups.join(', ') ) )

              groups.each do |g|

                unless( exists_usergroup?( g ) )
                  logger.warn( format( '  => group %s is not present. i must create them first', g ) )

                  result << add_usergroup( user_group: g, display_name: g )
                end

              end


              # pflichtfelder
              options = {
                user_name: user_name,
                display_name: display_name,
                email: email,
                groups: groups
              }

              # optionaler kram
              options['enable_notifications'] = true if( enable_notifications )
              options['pager'] = pager unless( pager.nil? )

              logger.debug( options )

              # create user
              result << add_user( options )
            end

          end
        end

        result
      end
    end

  end
end
