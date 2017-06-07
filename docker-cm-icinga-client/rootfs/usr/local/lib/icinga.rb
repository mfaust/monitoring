#!/usr/bin/ruby
#
#
#
#

# require 'rest-client'
# require 'openssl'
#
# require 'json'
# require 'net/http'
# require 'uri'

require 'icinga2'

require_relative 'logging'
require_relative 'utils/network'
require_relative 'cache'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'

require_relative 'icinga/tools'
require_relative 'icinga/queue'

# -------------------------------------------------------------------------------------------------------------------

class CMIcinga2 < Icinga2::Client

  include CMIcinga2::Tools
  include CMIcinga2::Queue

  def initialize( settings = {} )

    logger.debug( "CMIcinga2.initialize( #{settings} )" )

      @icingaHost           = settings.dig(:icinga, :host)            || 'localhost'
      @icingaApiPort        = settings.dig(:icinga, :api, :port)      || 5665
      @icingaApiUser        = settings.dig(:icinga, :api, :user)
      @icingaApiPass        = settings.dig(:icinga, :api, :password)
      @icingaCluster        = settings.dig(:icinga, :cluster)         || false
      @icingaSatellite      = settings.dig(:icinga, :satellite)
      @icingaNotifications  = settings.dig(:icinga, :notifications)   || false

      mqHost                = settings.dig(:mq, :host)                || 'localhost'
      mqPort                = settings.dig(:mq, :port)                || 11300
      @mqQueue              = settings.dig(:mq, :queue)               || 'mq-icinga'

      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      @icingaApiUrlBase     = sprintf( 'https://%s:%d', @icingaHost, @icingaApiPort )
      @nodeName             = Socket.gethostbyname( Socket.gethostname ).first

      mqSettings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => @mqQueue
      }

      super( settings )

      version              = '1.6.3'
      date                 = '2017-06-06'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Icinga2 Client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2017 CoreMedia' )
      logger.info( "  Backendsystem #{@icingaApiUrlBase}" )
      logger.info( sprintf( '    cluster enabled: %s', @icingaCluster ? 'true' : 'false' ) )
      if( @icingaCluster )
        logger.info( sprintf( '    satellite endpoint: %s', @icingaSatellite ) )
      end
      logger.info( sprintf( '    notifications enabled: %s', @icingaNotifications ? 'true' : 'false' ) )
      logger.info( '  used Services:' )
      logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      logger.info( "    - message Queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      logger.debug( sprintf( '  server   : %s', @icingaHost ) )
      logger.debug( sprintf( '  port     : %s', @icingaApiPort ) )
      logger.debug( sprintf( '  api url  : %s', @icingaApiUrlBase ) )
      logger.debug( sprintf( '  api user : %s', @icingaApiUser ) )
      logger.debug( sprintf( '  api pass : %s', @icingaApiPass ) )
      logger.debug( sprintf( '  node name: %s', @nodeName ) )

      @cache      = Cache::Store.new()
      @jobs       = JobQueue::Job.new()
      @mqConsumer = MessageQueue::Consumer.new( mqSettings )
      @mqProducer = MessageQueue::Producer.new( mqSettings )

      @database   = Storage::MySQL.new( {
        :mysql => {
          :host     => mysqlHost,
          :user     => mysqlUser,
          :password => mysqlPassword,
          :schema   => mysqlSchema
        }
      } )

  end

end


# EOF
