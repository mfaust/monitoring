#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.2.3

# -----------------------------------------------------------------------------

require 'yaml'
require 'rufus-scheduler'

require_relative '../lib/logging'
require_relative '../lib/cache'
require_relative '../lib/utils/network'
require_relative '../lib/storage'
require_relative '../lib/message-queue'

# -----------------------------------------------------------------------------

class Monitoring

  attr_reader :status, :message, :services

  include Logging

  def initialize( settings = {} )

    mqHost              = settings.dig(:mq, :host)      || 'localhost'
    mqPort              = settings.dig(:mq, :port)      || 11300
    mqQueue             = settings.dig(:mq, :queue)     || 'mq-rest-service'
    redisHost           = settings.dig(:redis, :host)   || 'localhost'
    redisPort           = settings.dig(:redis, :port)   || 6379

    @MQSettings = {
      :beanstalkHost  => mqHost,
      :beanstalkPort  => mqPort,
      :beanstalkQueue => mqQueue
    }

    @enabledDiscovery = true
    @enabledGrafana   = true
    @enabledIcinga    = true

    logger.level           = Logger::DEBUG

    version              = '2.4.92'
    date                 = '2017-05-17'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Monitoring Service' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - redis        : #{redisHost}:#{redisPort}" )
    logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{mqQueue}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    @cache      = Cache::Store.new()
    @mqConsumer = MessageQueue::Consumer.new( @MQSettings )
    @mqProducer = MessageQueue::Producer.new( @MQSettings )
    @redis      = Storage::RedisClient.new( { :redis => { :host => redisHost } } )

    scheduler   = Rufus::Scheduler.new
    scheduler.every( 60, :first_in => 1 ) do

      self.createNodeInformation()
    end

  end


  # create a cache about all known monitored nodes
  #
  def createNodeInformation()

    logger.debug( 'create node information ...' )

    result  = Hash.new()

    status  = @redis.nodes( { :status => Storage::RedisClient::OFFLINE } )
#     logger.debug( status )

#     # remove offline nodes
#     if( status.is_a?( Hash ) || status.is_a?( Array ) && status.count != 0 )
#
#       status = status.keys
#
#       status.each do |node|
#
#         logger.info( sprintf( 'delete offline node %s', node ) )
#
# #         @redis.removeDNS( { :short => node } )
#       end
#     end

    nodes   = @redis.nodes({ :status => Storage::RedisClient::ONLINE })
#     logger.debug( nodes )

    if( nodes.is_a?( Hash ) || nodes.is_a?( Array ) )

      if( nodes.count != 0 )

        if( nodes.is_a?( Hash ) )
          nodes = nodes.keys
        end

        nodes.each do |n|

#           logger.debug( n )

          hostData = self.checkAvailablility?( n )

          if( hostData == false )

            result = {
              :status  => 400,
              :message => sprintf( 'Host \'%s\' are not available (DNS Problem)', n )
            }

            logger.warn( result )

            next
          end

          result[n.to_s] ||= {}
          result[n.to_s][:dns] ||= {}
          result[n.to_s][:dns] = hostData

          hostConfiguration = self.getHostConfiguration( n )

          if( hostConfiguration != nil )
            hostConfigurationStatus  = hostConfiguration.dig(:status)  || 204
            hostConfigurationMessage = hostConfiguration.dig(:message)
          end

          if( hostConfigurationStatus == 200 )
            result[n.to_s][:custom_config] = hostConfigurationMessage
          end

          # get data from external services
          self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-icinga'  , :prio => 1, :payload => {} } )
          self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-grafana' , :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )
          self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-discover', :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )

#          sleep( 8 )

          resultArray = Array.new()
#           threads     = Array.new()

          discoveryStatus = Hash.new()
          grafanaStatus   = Hash.new()
          icingaStatus    = Hash.new()


          for y in 1..5

            r      = @mqConsumer.getJobFromTube('mq-discover-info')

            if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload', 'services' ) != nil )

              discoveryStatus = r
              break
            else
              logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-discover-info', y ) )
              sleep( 5 )
            end
          end

          for y in 1..2

            r      = @mqConsumer.getJobFromTube('mq-grafana-info')

            if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

              grafanaStatus = r
              break
            else
              logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-grafana-info', y ) )
              sleep( 5 )
            end
          end

          for y in 1..2

            r      = @mqConsumer.getJobFromTube('mq-icinga-info')

            if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

              icingaStatus = r
              break
            else
              logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-icinga-info', y ) )
              sleep( 5 )
            end
          end

#           discoveryStatus = @mqConsumer.getJobFromTube( 'mq-discover-info', true )
#           grafanaStatus   = @mqConsumer.getJobFromTube( 'mq-grafana-info', true )
#           icingaStatus    = @mqConsumer.getJobFromTube( 'mq-icinga-info', true )

          if( discoveryStatus )
            discoveryStatus = discoveryStatus.dig( :body, 'payload' ) || {}
            result[n.to_s][:discovery] ||= {}
            result[n.to_s][:discovery] = discoveryStatus
          end

          if( grafanaStatus )
            grafanaStatus = grafanaStatus.dig( :body, 'payload' ) || {}
            result[n.to_s][:grafana] ||= {}
            result[n.to_s][:grafana] = grafanaStatus
          end

          if( icingaStatus )
            icingaStatus = icingaStatus.dig( :body, 'payload' ) || {}
            result[n.to_s][:icinga] ||= {}
            result[n.to_s][:icinga] = icingaStatus
          end

        end

        @cache.set( 'information' , expiresIn: 60 ) { Cache::Data.new( result ) }

      else
        logger.debug( 'no nodes found' )
        @cache.unset( 'information' )
      end

    else
      logger.debug( 'no nodes found' )
      @cache.unset( 'information' )
    end

  end


  # check availability and create an DNS entry into our redis
  #
  def checkAvailablility?( host )

#     logger.debug( "checkAvailablility?( #{host} )" )

    hostInfo      = Utils::Network.resolv( host )

#     logger.debug( JSON.pretty_generate( hostInfo ) )

    ip            = hostInfo.dig(:ip)
    shortHostName = hostInfo.dig(:short)
    longHostName  = hostInfo.dig(:long)

    if( ip == nil || shortHostName == nil )
      return false
    else

      logger.debug( 'create DNS Entry' )

      @redis.createDNS( { :ip => ip, :short => shortHostName, :long => longHostName } )

      return hostInfo
    end

  end

  # -- MESSAGE-QUEUE ---------------------------------------------------------------------
  #
  def messageQueue( params = {} )

    command = params.dig(:cmd)
    node    = params.dig(:node)
    queue   = params.dig(:queue)
    data    = params.dig(:payload)
    prio    = params.dig(:prio)  || 65536
    ttr     = params.dig(:ttr)   || 10
    delay   = params.dig(:delay) || 2

    job = {
      cmd:  command,
      node: node,
      timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ),
      from: 'rest-service',
      payload: data
    }.to_json

    @mqProducer.addJob( queue, job, prio, ttr, delay )

  end

  # -- CONFIGURE ------------------------------------------------------------------------
  #
  def writeHostConfiguration( host, payload )

    status       = 500
    message      = 'initialize error'

    current = Hash.new()
    hash    = Hash.new()

    if( host.to_s != '' )

#       directory = self.createCacheDirectory( host )

      hash = JSON.parse( payload )

      hostInfo = Utils::Network.resolv( host )
      host     = hostInfo.dig(:short)

      @redis.createConfig( { :short => host , :data => hash } )

      status  = 200
      message = 'config successful written'

    end

    return JSON.pretty_generate( {
      :status  => status,
      :message => message
    } )

  end


  def getHostConfiguration( host )

    if( host.to_s != '' )

      hostInfo = Utils::Network.resolv( host )
      host     = hostInfo.dig(:short)

      data     = @redis.config( { :short => host } )

      # logger.debug( data )

      if( data != false )

       return {
          :status  => 200,
          :message => data
        }
      end

    end

    return {
      :status  => 204,
      :message => 'no configuration found'
    }

  end


  def removeHostConfiguration( host )

    status       = 500
    message      = 'initialize error'


    if( host.to_s != '' )

      hostInfo = Utils::Network.resolv( host )
      host     = hostInfo.dig(:short)

      data     = @redis.removeConfig( { :short => host } )

      if( data != false )
        status = 200
        message = 'configuration succesfull removed'
      else
        status  = 404
        message = 'No configuration found'
      end
    end

    return JSON.pretty_generate( {
      :status  => status,
      :message => message
    } )

  end


  # -- HOST -----------------------------------------------------------------------------
  #
#      example:
#      {
#        "force": true,
#        "discovery": false,
#        "icinga": false,
#        "grafana": false,
#        "tags": [
#          "development",
#          "git-0000000"
#        ],
#        "annotation": true,
#        "overview": true,
#        "config": {
#          "ports": [50199],
#          "display-name": "foo.bar.com",
#          "services": [
#            "cae-live-1": {},
#            "content-managment-server": { "port": 41000 }
#          ]
#        }
#      }

  def addHost( host, payload )

    logger.debug( sprintf( 'addHost( \'%s\', \'%s\' )', host, payload ) )

    status    = 500
    message   = 'initialize error'

    result    = Hash.new()
    hash      = Hash.new()

    if( host.to_s == '' )

      return JSON.pretty_generate( {
        :status  => 400,
        :message => 'no hostname given'
      } )

    end

    logger.info( sprintf( 'add node \'%s\' to monitoring', host ) )

    hostData = self.checkAvailablility?( host )

    if( hostData == false )

      return {
        :status  => 400,
        :message => 'Host are not available (DNS Problem)'
      }

    end

    force           = false
    enableDiscovery = @enabledDiscovery
    enabledGrafana  = @enabledGrafana
    enabledIcinga   = @enabledIcinga
    annotation      = true
    grafanaOverview = true
    services        = []
    tags            = []
    config          = {}

    if( payload.to_s != '' )

      hash = JSON.parse( payload )

      result[:request] = hash

      force           = hash.keys.include?('force')        ? hash['force']        : false
      enableDiscovery = hash.keys.include?('discovery')    ? hash['discovery']    : @enabledDiscovery
      enabledGrafana  = hash.keys.include?('grafana')      ? hash['grafana']      : @enabledGrafana
      enabledIcinga   = hash.keys.include?('icinga')       ? hash['icinga']       : @enabledIcinga
      annotation      = hash.keys.include?('annotation')   ? hash['annotation']   : true
      grafanaOverview = hash.keys.include?('overview')     ? hash['overview']     : true
      services        = hash.keys.include?('services')     ? hash['services']     : []
      tags            = hash.keys.include?('tags')         ? hash['tags']         : []
      config          = hash.keys.include?('config')       ? hash['config']       : {}
    end

    logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
    logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
    logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
    logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
    logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )
    logger.debug( sprintf( 'overview   : %s', grafanaOverview  ? 'true' : 'false' ) )
    logger.debug( sprintf( 'services   : %s', services ) )
    logger.debug( sprintf( 'tags       : %s', tags ) )
    logger.debug( sprintf( 'config     : %s', config ) )

    if( force == true )

      logger.info( 'force mode ...' )

      if( enabledGrafana == true )
        logger.info( 'remove grafana dashborads' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => payload, :prio => 0 } )
      end

      if( enabledIcinga == true )
        logger.info( 'remove icinga checks and notifications' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => payload, :prio => 0 } )
      end

      if( enableDiscovery == true )
        logger.info( 'remove node from discovery service' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => payload, :prio => 0 } )
      end

      logger.info( 'done' )
    end

    # now, we can write an own configiguration per node when we add them, hurray
    if( config.is_a?( Hash ) )

      short = hostData.dig( :short )

      @redis.createConfig( {
        :short => short,
        :data  => config
      } )

    end

    if( enableDiscovery == true )

      logger.info( 'add node to discovery service' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-discover', :payload => payload, :prio => 1, :delay => 1 } )
    end

    if( enabledGrafana == true )

      logger.info( 'create grafana dashborads' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-grafana', :payload => payload, :prio => 10, :ttr => 15, :delay => 15 } )
    end

    if( enabledIcinga == true  )

      logger.info( 'create icinga checks and notifications' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-icinga', :payload => payload, :prio => 10, :ttr => 15, :delay => 15 } )
    end

    # add annotation at last
    #
    if( annotation == true )

      logger.info( 'annotation for create' )
      self.addAnnotation( host, { 'command': 'create', 'argument': 'node' } )
    end


    discoveryResult = {
      :status  => 200,
      :message => 'send to MQ'
    }

    result[:status]                   = 200
    result[host.to_sym]             ||= {}
    result[host.to_sym][:request]   ||= {}
    result[host.to_sym][:request]     = payload
#    result[host.to_sym][:discovery] ||= {}
    result[host.to_sym][:discovery]   = 'the message queue is informed ...' # discoveryResult

    logger.debug( 'addHost() - done (or not)' )
    logger.debug( JSON.pretty_generate( result ) )

#     self.createNodeInformation()

    return JSON.pretty_generate( result )

  end

  # use the predefined cache
  #
  def listHost( host = nil, payload = nil )

#    logger.debug( "listHost( #{host}, #{payload} )" )

    request = payload.dig('rack.request.query_hash')
    short   = request.keys.include?('short')

    status  = 204
    result  = Hash.new()
    cache   = @cache.get( 'information' )

#    logger.debug( cache )

    if( cache == nil )

      result = {
        :status  => 204,
        :message => 'no hosts in monitoring found'
      }

      return JSON.pretty_generate( result )
    end



    if( host.to_s != '' )

      h = cache.dig( host.to_s )

      if ( h != nil )

        if( short == true )

          result[:host] = host
        else
          result[host.to_s] ||= {}
          result[host.to_s] = h
        end
        status = 200
      else

        status = 204
      end

    else

      if( cache != nil )

        if( short == true )

          result[:hosts] = cache.keys
        else
          result = cache
        end

        status = 200
      end

    end

    result[:status] = status

    return JSON.pretty_generate( result )

  end


#     example:
#     {
#       "force": true,
#       "icinga": false,
#       "grafana": false,
#       "annotation": true
#     }
  def removeHost( host, payload )

    logger.info( sprintf( 'remove node \'%s\' from monitoring', host ) )

    status    = 500
    message   = 'initialize error'

    if( host.to_s == '' )

      return {
        :status  => 400,
        :message => 'we need an node name for this'
      }
    end

    # --------------------------------------------------------------------

    result    = Hash.new()
    hash      = Hash.new()

    logger.info( sprintf( 'remove %s from monitoring', host ) )

    enableDiscovery = @enabledDiscovery
    enabledGrafana  = @enabledGrafana
    enabledIcinga   = @enabledIcinga
    annotation      = true

    if( payload != '' )

      hash = JSON.parse( payload )

      result[:request] = hash

      force           = hash.keys.include?('force')      ? hash['force']      : false
      enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
      enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
      annotation      = hash.keys.include?('annotation') ? hash['annotation'] : true
    end

    logger.debug( 'set node status to DELETE' )
    @redis.setStatus( { :short => host, :status => Storage::RedisClient::DELETE } )

    logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
    logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
    logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
    logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
    logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )

    result[host.to_sym] ||= {}

    if( annotation == true )
      logger.info( 'annotation for remove' )
      self.addAnnotation( host, { "command": "remove", "argument": "node" } )
    end

    if( enabledIcinga == true )
      logger.info( 'remove icinga checks and notifications' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => { "force" => true }, :prio => 0 } )
    end
    if( enabledGrafana == true )
      logger.info( 'remove grafana dashborads' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => { "force" => true }, :prio => 0 } )
    end

    if( enableDiscovery == true )
      logger.info( 'remove node from discovery service' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => { "force" => true }, :prio => 0 } )
    end

    if( force == true )
      logger.info( 'remove configuration from db (force mode)' )
      @redis.removeConfig( { :short => host } )
    end

    discoveryResult = {
      :status  => 200,
      :message => 'send to MQ'
    }

    result[host.to_sym] ||= {}
    result[host.to_sym][:request]   ||= {}
    result[host.to_sym][:request]     = payload
    result[host.to_sym][:discovery] ||= {}
    result[host.to_sym][:discovery]   = discoveryResult

#     sleep(4)
#
#     self.createNodeInformation()

    logger.debug( JSON.pretty_generate( result ) )

    return JSON.pretty_generate( result )

  end


  # -- ANNOTATIONS ----------------------------------------------------------------------
  #

  def addAnnotation( host, payload )

    status                = 500
    message               = 'initialize error'

    result                = Hash.new()
    hash                  = Hash.new()

    if( host.to_s != '' )

      command      = nil
      argument     = nil
      message      = nil
      description  = nil
      tags         = []

      if( payload != '' )

        if( payload.is_a?( String ) )

          hash         = JSON.parse( payload )

          command      = hash.dig('command')
          argument     = hash.dig('argument')
          message      = hash.dig('message')
          description  = hash.dig('description')
          tags         = hash.dig('tags')  || []

        else

          hash         = payload

          command      = hash.dig(:command)
          argument     = hash.dig(:argument)
          message      = hash.dig(:message)
          description  = hash.dig(:description)
          tags         = hash.dig(:tags)  || []

        end

        result[:request] = hash

        if( command == 'create' || command == 'remove' )
#         example:
#         {
#           "command": "create"
#         }
#
#         {
#           "command": "destroy"
#         }

          message     = nil
          description = nil
          tags        = []
          self.messageQueue( { :cmd => command, :node => host, :queue => 'mq-graphite', :payload => { "timestamp": Time.now().to_i, "node" => host } } )

        elsif( command == 'loadtest' && ( argument == 'start' || argument == 'stop' ) )

#         example:
#         {
#           "command": "loadtest",
#           "argument": "start"
#         }
#
#         {
#           "command": "loadtest",
#           "argument": "stop"
#         }

          message     = nil
          description = nil
          tags        = []

          self.messageQueue( { :cmd => 'loadtest', :node => host, :queue => 'mq-graphite', :payload => { "timestamp": Time.now().to_i, "argument" => argument } } )

        elsif( command == 'deployment' )

#         example:
#         {
#           "command": "deployment",
#           "message": "version 7.1.50",
#           "tags": [
#             "development",
#             "git-0000000"
#           ]
#         }
          description = nil
          self.messageQueue( { :cmd => 'deployment', :node => host, :queue => 'mq-graphite', :payload => { "timestamp": Time.now().to_i, "message" => message, "tags" => tags } } )

        else
#         example:
#         {
#           "command": "",
#           "message": "date: 2016-12-24, last-cristmas",
#           "description": "never so ho-ho-ho",
#           "tags": [
#             "development",
#             "git-0000000"
#           ]
#         }
          self.messageQueue( { :cmd => 'general', :node => host, :queue => 'mq-graphite', :payload => { "timestamp": Time.now().to_i, "message" => message, "tags" => tags, "description" => description } } )

        end

        status    = 200
        message   = 'annotation succesfull created'
      else

        status    = 400
        message   = 'annotation data not set'

      end

    end

    return JSON.pretty_generate( {
      :status  => status,
      :message => message
    } )

  end



  # -- FUTURE ---------------------------------------------------------------------------
  #

  def addGrafanaGroupOverview( hosts, force = false )

    grafanaResult = @grafana.addGroupOverview( hosts, force )
#    grafanaStatus = grafanaResult[:status]

    return {
      :status  => grafanaResult[:status],
      :message => grafanaResult[:message]
    }

  end






end

# ------------------------------------------------------------------------------------------

# EOF
