#!/usr/bin/ruby
#
#
#
#

require 'icinga2'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'cache'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'

require_relative 'icinga/version'
require_relative 'icinga/tools'
require_relative 'icinga/queue'

# -------------------------------------------------------------------------------------------------------------------

class CMIcinga2 < Icinga2::Client

  include CMIcinga2::Tools
  include CMIcinga2::Queue
  include CMIcinga2::Version
#   include CMIcinga2::Data

  def initialize( settings = {} )

    logger.debug( "CMIcinga2.initialize( #{settings} )" )

      @icinga_host           = settings.dig(:icinga, :host)            || 'localhost'
      @icinga_api_port       = settings.dig(:icinga, :api, :port)      || 5665
      @icinga_api_user       = settings.dig(:icinga, :api, :user)
      @icinga_api_pass       = settings.dig(:icinga, :api, :password)
      @icinga_cluster        = settings.dig(:icinga, :cluster)         || false
      @icinga_satellite      = settings.dig(:icinga, :satellite)
      @icinga_notifications  = settings.dig(:icinga, :notifications)   || false

      mq_host                = settings.dig(:mq, :host)                || 'localhost'
      mq_port                = settings.dig(:mq, :port)                || 11300
      @mq_queue              = settings.dig(:mq, :queue)               || 'mq-icinga'

      mysql_host             = settings.dig(:mysql, :host)
      mysql_schema           = settings.dig(:mysql, :schema)
      mysql_user             = settings.dig(:mysql, :user)
      mysql_password         = settings.dig(:mysql, :password)

      @icinga_api_url_base   = format('https://%s:%d', @icinga_host, @icinga_api_port )
      @node_name             = Socket.gethostbyname(Socket.gethostname ).first

      mq_settings = {
        :beanstalkHost  => mq_host,
        :beanstalkPort  => mq_port,
        :beanstalkQueue => @mq_queue
      }

      super( settings )

      version              = CMIcinga2::Version::VERSION
      date                 = CMIcinga2::Date::DATE

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Icinga2 Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2017 CoreMedia' )
      logger.info( "  Backendsystem #{@icinga_api_url_base}" )
      logger.info( format( '    cluster enabled: %s', @icinga_cluster ? 'true' : 'false' ) )
      if( @icinga_cluster )
        logger.info( format('    satellite endpoint: %s', @icinga_satellite ) )
      end
      logger.info( format('    notifications enabled: %s', @icinga_notifications ? 'true' : 'false' ) )
      logger.info( '  used Services:' )
      logger.info( "    - mysql        : #{mysql_host}@#{mysql_schema}" )
      logger.info( "    - message Queue: #{mq_host}:#{mq_port}/#{@mq_queue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      logger.debug( format(' server   : %s', @icinga_host ) )
      logger.debug( format(' port     : %s', @icinga_api_port ) )
      logger.debug( format(' api url  : %s', @icinga_api_url_base ) )
      logger.debug( format(' api user : %s', @icinga_api_user ) )
      logger.debug( format(' api pass : %s', @icinga_api_pass ) )
      logger.debug( format(' node name: %s', @node_name ) )

      @cache      = Cache::Store.new()
      @jobs       = JobQueue::Job.new()
      @mq_consumer = MessageQueue::Consumer.new(mq_settings )
      @mq_producer = MessageQueue::Producer.new(mq_settings )

      @database   = Storage::MySQL.new( {
        :mysql => {
          :host     => mysql_host,
          :user     => mysql_user,
          :password => mysql_password,
          :schema   => mysql_schema
        }
      } )

  end

end


# EOF
