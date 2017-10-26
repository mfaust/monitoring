#!/usr/bin/ruby
#
#
#
#

require 'grafana'

require_relative 'logging'
require_relative 'monkey'
require_relative 'cache'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'mbean'

require_relative 'cm_grafana/version'
require_relative 'cm_grafana/configure_server'
require_relative 'cm_grafana/queue'
require_relative 'cm_grafana/coremedia/tools'
require_relative 'cm_grafana/coremedia/dashboard'

class CMGrafana

  include Logging
  include Grafana
  include CMGrafana::Version
  include CMGrafana::ServerConfiguration
  include CMGrafana::Queue
  include CMGrafana::Coremedia::Tools
  include CMGrafana::Coremedia::Dashboard
  include CMGrafana::Coremedia::Templates
  include CMGrafana::Coremedia::Annotations

  def initialize( settings = {} )

    host                 = settings.dig(:grafana, :host)          || 'localhost'
    port                 = settings.dig(:grafana, :port)          || 80
    @user                = settings.dig(:grafana, :user)          || 'admin'
    @password            = settings.dig(:grafana, :password)
    url_path             = settings.dig(:grafana, :url_path)
    ssl                  = settings.dig(:grafana, :ssl)           || false
    @timeout             = settings.dig(:grafana, :timeout)       || 5
    @open_timeout        = settings.dig(:grafana, :open_timeout)  || 5
    @http_headers        = settings.dig(:grafana, :headers)       || {}
    server_config_file   = settings.dig(:grafana, :server_config_file)
    @template_directory  = settings.dig(:templateDirectory)       || '/usr/local/share/templates/grafana'

    mq_host              = settings.dig(:mq, :host)               || 'localhost'
    mq_port              = settings.dig(:mq, :port)               || 11300
    @mq_queue            = settings.dig(:mq, :queue)              || 'mq-grafana'

    redis_host           = settings.dig(:redis, :host)
    redis_port           = settings.dig(:redis, :port)            || 6379

    mysql_host           = settings.dig(:mysql, :host)
    mysql_schema         = settings.dig(:mysql, :schema)
    mysql_user           = settings.dig(:mysql, :user)
    mysql_password       = settings.dig(:mysql, :password)


    mq_settings = {
      :beanstalkHost  => mq_host,
      :beanstalkPort  => mq_port,
      :beanstalkQueue => @mq_queue
    }

    mysql_settings = {
      :mysql => {
        :host     => mysql_host,
        :user     => mysql_user,
        :password => mysql_password,
        :schema   => mysql_schema
      }
    }

    super( settings )

    @debug  = false
    @logger = logger

    version       = CMGrafana::Version::VERSION
    date          = CMGrafana::Date::DATE

    logger.info( '-----------------------------------------------------------------' )
    logger.info( " CoreMedia - Grafana Client - gem Version #{Grafana::VERSION}" )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - grafana      : #{@url}" )
    logger.info( "    - redis        : #{redis_host}:#{redis_port}" )
    logger.info( "    - mysql        : #{mysql_host}@#{mysql_schema}" )
    logger.info( "    - message queue: #{mq_host}:#{mq_port}/#{@mq_queue}" )
    logger.info( '-----------------------------------------------------------------' )


    begin

      @logged_in = login( { :user => @user, :password => @password } )
    rescue => e

      if( server_config_file.nil? )

        logger.error( 'no server configuration found' )
      else

        # read config file
        config = read_config_file( config_file: server_config_file )

        if( config.nil? )

          logger.error( 'no configuration found')

          server_config_file = nil

        else

          admin_user = config.select { |x| x == 'admin_user' }.values
          admin_user = admin_user.first if( admin_user.is_a?(Array) )

          admin_login_name = admin_user.dig('login_name')
          admin_password   = admin_user.dig('password')

          logger.debug( format( 'use new admin credetials for \'%s\' :: %s', admin_login_name, admin_password ) )

          @user      = admin_login_name
          @password  = admin_password
          @logged_in = login( { :user => @user, :password => @password, :max_retries => 10 } )
        end
      end

    end

    cfg = configure_server( config_file: server_config_file ) unless( server_config_file.nil? )

    @redis        = Storage::RedisClient.new( { :redis => { :host => redis_host } } )
    @mbean        = MBean::Client.new( { :redis => @redis } )
    @cache        = Cache::Store.new()
    @jobs         = JobQueue::Job.new()
    @mq_consumer  = MessageQueue::Consumer.new(mq_settings )
    @mq_producer  = MessageQueue::Producer.new(mq_settings )
    @database     = Storage::MySQL.new( mysql_settings )

  end

end

