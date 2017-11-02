
require_relative 'version'
require_relative 'annotations'
require_relative 'tools'
require_relative 'information'
require_relative 'host'

module Monitoring

  class Client

    include Logging

    include Monitoring::Annotations
    include Monitoring::Tools
    include Monitoring::Information
    include Monitoring::Host

    def initialize( settings = {} )

      raise ArgumentError.new('only Hash are allowed') unless( settings.is_a?(Hash) )
      raise ArgumentError.new('missing settings') if( settings.size.zero? )

      mqHost              = settings.dig(:mq, :host)      || 'localhost'
      mqPort              = settings.dig(:mq, :port)      || 11300
      mqQueue             = settings.dig(:mq, :queue)     || 'mq-rest-service'
      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)
      mysqlHost           = settings.dig(:mysql, :host)
      mysqlSchema         = settings.dig(:mysql, :schema)
      mysqlUser           = settings.dig(:mysql, :user)
      mysqlPassword       = settings.dig(:mysql, :password)

      mq_settings = {
        :beanstalkHost  => mqHost,
        :beanstalkPort  => mqPort,
        :beanstalkQueue => mqQueue
      }

      mysql_settings = {
        :mysql => {
          :host     => mysqlHost,
          :user     => mysqlUser,
          :password => mysqlPassword,
          :schema   => mysqlSchema
        }
      }

      @enabledDiscovery = true
      @enabledGrafana   = true
      @enabledIcinga    = true

      logger.level         = Logger::INFO

      version              = Monitoring::VERSION
      date                 = Monitoring::DATE

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Monitoring Service' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 CoreMedia' )
      logger.info( '  used Services:' )
      logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
      logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @cache       = MiniCache::Store.new()
      @redis       = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
      @mq_consumer = MessageQueue::Consumer.new( mq_settings )
      @mq_producer = MessageQueue::Producer.new( mq_settings )
      @database    = Storage::MySQL.new( mysql_settings )

    end


  end

end
