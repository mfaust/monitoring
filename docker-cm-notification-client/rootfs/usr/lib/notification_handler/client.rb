
require 'yaml'

require_relative 'version'
require_relative 'queue'

module NotificationHandler

  class Client

    include Logging

    include NotificationHandler::Version
    include NotificationHandler::Queue

    def initialize( settings )

      mq_host  = settings.dig(:mq, :host)  || 'localhost'
      mq_port  = settings.dig(:mq, :port)  || 11300
      mq_queue = settings.dig(:mq, :queue) || 'mq-notification'


      mq_settings = {
        beanstalkHost: mq_host,
        beanstalkPort: mq_port,
        beanstalkQueue: mq_queue
      }

      version              = NotificationHandler::Version::VERSION # '1.4.2'
      date                 = NotificationHandler::Date::DATE       # '2017-06-04'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Notification Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - message Queue: #{mq_host}:#{mq_port}/#{mq_queue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @mq_consumer  = MessageQueue::Consumer.new( mq_settings )
      @mq_producer  = MessageQueue::Producer.new( mq_settings )

      @mq_queue = mq_queue

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
