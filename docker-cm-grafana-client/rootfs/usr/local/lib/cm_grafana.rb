#!/usr/bin/ruby
#
# 15.10.2017 - Bodo Schulz
#
#
# v1.95.1

# -----------------------------------------------------------------------------

require 'grafana'

require_relative 'logging'
require_relative 'cache'
require_relative 'job-queue'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'mbean'

require_relative 'grafana/queue'

require_relative 'grafana/coremedia/tools'
require_relative 'grafana/coremedia/dashboard'

# -----------------------------------------------------------------------------

class CMGrafana

  include Grafana
  include Grafana::Login

  include Logging

#   include CMGrafana::Queue
#   include CMGrafana::Coremedia::Tools
#   include CMGrafana::Coremedia::Dashboard
#   include CMGrafana::Coremedia::Templates
#   include CMGrafana::Coremedia::Annotations
#   include CMGrafana::Coremedia::Tags

  def initialize( settings )

#     logger.debug( CMGrafana.methods.sort )
#     logger.debug( Grafana.methods.sort )

    # logger.debug( "CMGrafana.initialize( #{settings} )" )

    host                = settings.dig(:grafana, :host)          || 'localhost'
    port                = settings.dig(:grafana, :port)          || 80
    @user               = settings.dig(:grafana, :user)          || 'admin'
    @password           = settings.dig(:grafana, :password)      || ''
    urlPath             = settings.dig(:grafana, :url_path)      || ''
    ssl                 = settings.dig(:grafana, :ssl)           || false
    @timeout            = settings.dig(:grafana, :timeout)       || 5
    @open_timeout       = settings.dig(:grafana, :open_timeout)  || 5
    @http_headers       = settings.dig(:grafana, :headers)       || {}

    @debug = true

    super(
  :grafana => {
    :host              => host,
    :port              => port,
    :user              => @user,
    :password          => @password,
               :debug => true
              }
    )

    @template_directory = settings.dig(:templateDirectory)       || '/usr/local/share/templates/grafana'

    mqHost              = settings.dig(:mq, :host)               || 'localhost'
    mqPort              = settings.dig(:mq, :port)               || 11300
    @mq_queue           = settings.dig(:mq, :queue)              || 'mq-grafana'

    redisHost           = settings.dig(:redis, :host)
    redisPort           = settings.dig(:redis, :port)            || 6379

    mysqlHost           = settings.dig(:mysql, :host)
    mysqlSchema         = settings.dig(:mysql, :schema)
    mysqlUser           = settings.dig(:mysql, :user)
    mysqlPassword       = settings.dig(:mysql, :password)

    @mq_settings = {
      :beanstalkHost  => mqHost,
      :beanstalkPort  => mqPort,
      :beanstalkQueue => @mq_queue
    }

    @timeout      = 5 if( @timeout.to_i <= 0 )
    @open_timeout = 5 if( @open_timeout.to_i <= 0 )

    proto        = ( ssl == true ? 'https' : 'http' )
    @url  = sprintf( '%s://%s:%s%s', proto, host, port, urlPath )

    @api_instance = nil
    @loggedIn     = false

    # super # ( settings )

    version       = '1.95.1'
    date          = '2017-10-15'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Grafana Client' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - grafana      : #{host}:#{port}#{urlPath}" )
    logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
    logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
    logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mq_queue}" )
    logger.info( '-----------------------------------------------------------------' )


#     @redis       = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
#     @mbean       = MBean::Client.new( { :redis => @redis } )
#     @cache       = Cache::Store.new()
#     @jobs        = JobQueue::Job.new()
#     @mqConsumer  = MessageQueue::Consumer.new( @mq_settings )
#     @mqProducer  = MessageQueue::Producer.new( @mq_settings )

#     @database    = Storage::MySQL.new({
#       :mysql => {
#         :host     => mysqlHost,
#         :user     => mysqlUser,
#         :password => mysqlPassword,
#         :schema   => mysqlSchema
#       }
#     })

    @loggedIn = login( { :user => @user, :password => @password } )
  end

end

# EOF
