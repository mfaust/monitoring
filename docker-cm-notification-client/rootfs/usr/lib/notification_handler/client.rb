
require 'yaml'

require_relative 'version'
require_relative 'sender'
require_relative 'storage'

module NotificationHandler

  class Client

    include Logging

    include NotificationHandler::Version
    include NotificationHandler::Sender
    include NotificationHandler::Storage

    def initialize( settings = {} )

      version              = NotificationHandler::Version::VERSION # '1.4.2'
      date                 = NotificationHandler::Date::DATE       # '2017-06-04'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Notification Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2017 CoreMedia' )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      read_config
    end


    def read_config()

        file = '/etc/notification.yml'

        if( File.exist?(file) )

          begin
            @config  = YAML.load_file(file)

            logger.debug( @config )

          rescue YAML::ParserError => e

            logger.error( 'wrong result (no yaml)')
            logger.error( e )
          end
        end

    end

  end
end
