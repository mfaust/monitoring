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
    redisHost           = settings.dig(:redis, :host)
    redisPort           = settings.dig(:redis, :port)
    mysqlHost           = settings.dig(:mysql, :host)
    mysqlSchema         = settings.dig(:mysql, :schema)
    mysqlUser           = settings.dig(:mysql, :user)
    mysqlPassword       = settings.dig(:mysql, :password)

    @MQSettings = {
      :beanstalkHost  => mqHost,
      :beanstalkPort  => mqPort,
      :beanstalkQueue => mqQueue
    }

    @enabledDiscovery = true
    @enabledGrafana   = true
    @enabledIcinga    = true

    logger.level           = Logger::DEBUG

    version              = '2.4.112'
    date                 = '2017-06-22'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Monitoring Service' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - mysql        : #{mysqlHost}@#{mysqlSchema}" )
    logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{mqQueue}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    @cache      = Cache::Store.new()
    @redis      = Storage::RedisClient.new( { :redis => { :host => redisHost } } )
    @mqConsumer = MessageQueue::Consumer.new( @MQSettings )
    @mqProducer = MessageQueue::Producer.new( @MQSettings )

    @database   = Storage::MySQL.new({
      :mysql => {
        :host     => mysqlHost,
        :user     => mysqlUser,
        :password => mysqlPassword,
        :schema   => mysqlSchema
      }
    })

  end


  # get informations for one or all nodes back
  #
  def nodeInformations( params = {} )

#     logger.debug( "nodeInformations( #{params} )" )

    host            = params.dig(:host)
    status          = params.dig(:status) || [ Storage::MySQL::ONLINE, Storage::MySQL::PREPARE ]
    fullInformation = params.dig(:full)   || false

    ip              = nil
    short           = nil
    fqdn            = nil

    result  = Hash.new()

    if( host != nil )

      ip, short, fqdn = self.nsLookup( host )

      if( ip == nil && short == nil && fqdn == nil )

        return nil
      end

      params = { :ip => ip, :short => short, :fqdn => fqdn, :status => status }
    else

      params = { :status => status }
    end

    # get nodes with ONLINE or PREPARE state
    #
    nodes = @database.nodes( params )

    if( nodes.is_a?( Array ) && nodes.count != 0 )

      nodes.each do |n|

        if( ip == nil && short == nil && fqdn == nil )

          ip, short, fqdn = self.nsLookup( n )

          if( ip == nil && short == nil && fqdn == nil )

            result = {
              :status  => 400,
              :message => sprintf( 'Host \'%s\' are not available (DNS Problem)', n )
            }

            logger.warn( result )

            next
          end

        end

        result[n.to_s] ||= {}

        # DNS data
        #
        result[n.to_s][:dns] ||= { 'ip' => ip, 'short' => short, 'fqdn' => fqdn }

        status  = @database.status( { :ip => ip, :short => short, :fqdn => fqdn } )
        # {"ip"=>"192.168.252.100", "name"=>"blueprint-box", "fqdn"=>"blueprint-box", "status"=>"online", "creation"=>2017-06-07 11:07:57 +0000}

        created = status.dig('creation')
        message = status.dig('status')

        # STATUS data
        #
        result[n.to_s][:status] ||= { 'created' => created, 'status' => message }

        hostConfiguration = @database.config( { :ip => ip, :short => short, :fqdn => fqdn } )

        if( hostConfiguration != nil )
          result[n.to_s][:custom_config] = hostConfiguration
        end

        # get discovery data
        #
        discoveryData = @database.discoveryData( { :ip => ip, :short => short, :fqdn => fqdn } )

        if( discoveryData != nil )

          discoveryData.each do |a,d|

            d.reject! { |k| k == 'application' }
            d.reject! { |k| k == 'template' }
          end

          result[n.to_s][:services] ||= discoveryData

        end

        # realy needed?
        #
          if( fullInformation != nil && fullInformation == true )

            # get data from external services
            #
            self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-grafana' , :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )
            self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-icinga'  , :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )

            sleep( 1 )

            grafanaStatus   = Hash.new()
            icingaStatus    = Hash.new()

            for y in 1..4

              r      = @mqConsumer.getJobFromTube('mq-grafana-info')

#               logger.debug( r.dig( :body, 'payload' ) )

              if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

                grafanaStatus = r
                break
              else
#                 logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-grafana-info', y ) )
                sleep( 2 )
              end
            end

            for y in 1..4

              r      = @mqConsumer.getJobFromTube('mq-icinga-info')

#               logger.debug( r.dig( :body, 'payload' ) )

              if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

                icingaStatus = r
                break
              else
#                 logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-icinga-info', y ) )
                sleep( 2 )
              end
            end

            if( grafanaStatus )
              grafanaStatus = grafanaStatus.dig( :body, 'payload' ) || {}
              result[n.to_s][:grafana] ||= grafanaStatus
            end

            if( icingaStatus )
              icingaStatus = icingaStatus.dig( :body, 'payload' ) || {}
              result[n.to_s][:icinga] ||= icingaStatus
            end
          end


        ip    = nil
        short = nil
        fqdn  = nil
      end
    end

    return result

  end


  def nsLookup( name, expire = 120 )

    # DNS
    #
    cache_key = sprintf( 'dns::%s', name )

    logger.debug("cache_key: #{cache_key}")

    ip       = nil
    short    = nil
    fqdn     = nil

    dns      = @cache.get( cache_key )

    if( dns == nil )

      # create DNS Information
      dns      = Utils::Network.resolv( name )

      ip    = dns.dig(:ip)
      short = dns.dig(:short)
      fqdn  = dns.dig(:long)

      if( ip != nil && short != nil && fqdn != nil )

        @redis.set(format('dns::%s',fqdn), { 'ip': ip, 'short': short, 'long': fqdn }.to_json, 320 )
        @cache.set(cache_key , expiresIn: expire ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
      else
        logger.error( 'no DNS data found!' )
        logger.error( " => #{dns}" )

        return nil, nil, nil
      end
    else

      ip    = dns.dig(:ip)
      short = dns.dig(:short)
      fqdn  = dns.dig(:long)

    end

    logger.debug( "redis: #{@redis.get(format('dns::%s',fqdn))}" )

    #
    # ------------------------------------------------

#     dns    = @database.dnsData( { :ip => ip, :short => short, :fqdn => fqdn } )
#
#     if( dns == nil )
#
#       status = @database.createDNS( { :ip => ip, :short => short, :fqdn => fqdn } )
#
#       @cache.set( hostname , expiresIn: expire ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
#     end

#     logger.debug( sprintf( '  ip   %s ', ip ) )
#     logger.debug( sprintf( '  host %s ', short ) )
#     logger.debug( sprintf( '  fqdn %s ', fqdn ) )

    return ip, short, fqdn

  end


  def nodeExists?( host )

    logger.debug( "nodeExists?( #{host} )" )

    ip, short, fqdn = self.nsLookup( host )

    d = self.nodeInformations( { :host => fqdn } )

    if( d == nil )
      return false
    end

    if( d.keys.first == fqdn )
      return true
    else
      return false
    end

#     cache   = @cache.get( 'information' )
#
#     if( cache == nil )
#       return false
#     end
#
#     h = cache.dig( node.to_s )
#
#     if ( h == nil )
#       return false
#     else
#       return true
#     end

  end

  # check availability and create an DNS entry into our redis
  #
  def checkAvailablility?( host )

    ip, short, fqdn = self.nsLookup( host )

    if( ip == nil && short == nil && fqdn == nil )
      return false
    end

    return {
      :ip    => ip,
      :short => short,
      :fqdn  => fqdn
    }

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
#   def writeHostConfiguration( host, payload )
#
#     status       = 500
#     message      = 'initialize error'
#
#     current = Hash.new()
#     hash    = Hash.new()
#
#     if( host.to_s != '' )
#
# #       directory = self.createCacheDirectory( host )
#
#       hash = JSON.parse( payload )
#
#       hostInfo = Utils::Network.resolv( host )
#       host     = hostInfo.dig(:short)
#
#       @redis.createConfig( { :short => host , :data => hash } )
#
#       status  = 200
#       message = 'config successful written'
#
#     end
#
#     return JSON.pretty_generate( {
#       :status  => status,
#       :message => message
#     } )
#
#   end
#
#
#   def getHostConfiguration( host )
#
#     if( host.to_s != '' )
#
#       hostInfo = Utils::Network.resolv( host )
#       host     = hostInfo.dig(:short)
#
#       data     = @redis.config( { :short => host } )
#
#       # logger.debug( data )
#
#       if( data != false )
#
#        return {
#           :status  => 200,
#           :message => data
#         }
#       end
#
#     end
#
#     return {
#       :status  => 204,
#       :message => 'no configuration found'
#     }
#
#   end
#
#
#   def removeHostConfiguration( host )
#
#     status       = 500
#     message      = 'initialize error'
#
#
#     if( host.to_s != '' )
#
#       hostInfo = Utils::Network.resolv( host )
#       host     = hostInfo.dig(:short)
#
#       data     = @redis.removeConfig( { :short => host } )
#
#       if( data != false )
#         status = 200
#         message = 'configuration succesfull removed'
#       else
#         status  = 404
#         message = 'No configuration found'
#       end
#     end
#
#     return JSON.pretty_generate( {
#       :status  => status,
#       :message => message
#     } )
#
#   end
#

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
#          "display_name": "foo.bar.com",
#          "services": [
#            "cae-live-1": {},
#            "content-managment-server": { "port": 41000 }
#          ]
#        }
#      }

  def addHost( host, payload )

#     logger.debug( sprintf( 'addHost( \'%s\', \'%s\' )', host, payload ) )

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

    # --------------------------------------------------------------------

    logger.info( sprintf( 'add node \'%s\' to monitoring', host ) )

    alreadyInMonitoring = self.nodeExists?( host )

#     logger.debug( alreadyInMonitoring ? 'true' : 'false' )

    hostData = self.checkAvailablility?( host )

    if( hostData == false )

      return JSON.pretty_generate({
        :status  => 400,
        :message => 'Host are not available (DNS Problem)'
      })

    end

    logger.debug( JSON.pretty_generate( hostData ) )

    ip              = hostData.dig(:ip)
    short           = hostData.dig(:short)
    fqdn            = hostData.dig(:fqdn)

    force           = false
    enableDiscovery = @enabledDiscovery
    enabledGrafana  = @enabledGrafana
    enabledIcinga   = @enabledIcinga
    annotation      = true
    grafanaOverview = true
    services        = []
    tags            = []
    config          = {}

    result[host.to_s] ||= {}

    if( payload.to_s != '' )

      hash = JSON.parse(payload)

      result[host.to_s]['request'] = hash

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

#    logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'overview   : %s', grafanaOverview  ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'services   : %s', services ) )
#    logger.debug( sprintf( 'tags       : %s', tags ) )
#    logger.debug( sprintf( 'config     : %s', config ) )


    if( force == false && alreadyInMonitoring == true )
      logger.warn( "node '#{host}' is already in monitoring" )

      return JSON.pretty_generate( {
        'status'  => 200,
        'message' => "node '#{host}' is already in monitoring"
      })
    end

    # insert the DNS data into the payload
    #
    if( payload.is_a?(String) && payload.size != 0 )
      payload = JSON.parse(payload)
      payload['dns'] = hostData
    end

    if( payload.is_a?(String) && payload.size == 0 )
      payload = { 'dns' => hostData }
    end
    payload = JSON.generate(payload)

    if( force == true )

      logger.info( 'force mode ...' )

      if( enabledGrafana == true )
        logger.info( 'remove grafana dashborads' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => payload, :prio => 1 } )
      end

      if( enabledIcinga == true )
        logger.info( 'remove icinga checks and notifications' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => payload, :prio => 1 } )
      end

      if( enableDiscovery == true )
        logger.info( 'remove node from discovery service' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => payload, :prio => 1 } )
      end

      sleep(2)

#       logger.debug( 'remove configuration' )
      status = @database.removeConfig( { :ip => ip, :short => short, :fqdn => fqdn } )

      logger.info( 'done' )

      sleep(2)
    end


    # create a valid DNS entry
    #
    status = @database.createDNS( { :ip => ip, :short => short, :fqdn => fqdn } )

    # now, we can write an own configiguration per node when we add them, hurray
    #
    if( config.is_a?( Hash ) )

#       logger.debug( "write configuration: #{config}" )
      status = @database.createConfig( { :ip => ip, :short => short, :fqdn => fqdn, :data => config } )
    end

    if( enableDiscovery == true )

      logger.info( 'add node to discovery service' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-discover', :payload => payload, :prio => 1, :delay => 2 } )
    end

    if( enabledGrafana == true )

      logger.info( 'create grafana dashborads' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-grafana', :payload => payload, :prio => 10, :ttr => 15, :delay => 10 } )
    end

    if( enabledIcinga == true  )

      logger.info( 'create icinga checks and notifications' )
      self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-icinga', :payload => payload, :prio => 10, :ttr => 15, :delay => 10 } )
    end

    # add annotation at last
    #
    if( annotation == true )

      logger.info( 'annotation for create' )
      self.addAnnotation( host, { 'command' => 'create', 'argument' => 'node', 'config' => config } )
    end

    result['status']    = 200
    result['message']   = 'the message queue is informed ...'

    return JSON.pretty_generate( result )

  end

  #  - http://localhost/api/v2/host
  #  - http://localhost/api/v2/host?short
  #  - http://localhost/api/v2/host/blueprint-box
  #
  def listHost( host = nil, payload = nil )

    data = self.nodeInformations()

    request = payload.dig('rack.request.query_hash')
    short   = request.keys.include?('short')

    logger.debug( data )

    result  = Hash.new()

    if( data == nil || data.count == 0 )

      return JSON.pretty_generate({
        :status  => 204,
        :message => 'no hosts in monitoring found'
      })
    end



    if( host.to_s != '' )

      h = data.dig( host.to_s )

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

      if( data != nil )

        if( short == true )

          result[:hosts] = data.keys
        else
          result = data
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

    status    = 500
    message   = 'initialize error'

    if( host.to_s == '' )

      return JSON.pretty_generate( {
        :status  => 400,
        :message => 'no hostname given'
      } )

    end

    # --------------------------------------------------------------------

    logger.info( sprintf( 'remove node \'%s\' from monitoring', host ) )

    alreadyInMonitoring = self.nodeExists?( host )
    hostData            = self.checkAvailablility?( host )

    if( hostData == false )
      logger.warn( "DNS PROBLEMS" )

      return JSON.pretty_generate( {
        'status'  => 404,
        'message' => "we have problems with our dns to resolve '#{host}' :("
      })
    end

    result    = Hash.new()
    hash      = Hash.new()

    enableDiscovery = @enabledDiscovery
    enabledGrafana  = @enabledGrafana
    enabledIcinga   = @enabledIcinga
    annotation      = true

    result[host.to_s] ||= {}

    if( payload != '' )

      hash = JSON.parse( payload )

      result[host.to_s]['request'] = hash

      force           = hash.keys.include?('force')      ? hash['force']      : false
      enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
      enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
      annotation      = hash.keys.include?('annotation') ? hash['annotation'] : true
    end

    if( alreadyInMonitoring == false && force == false )
      logger.warn( "node '#{host}' is not in monitoring" )

      return JSON.pretty_generate( {
        'status'  => 200,
        'message' => "node '#{host}' is not in monitoring"
      })
    end

    if( alreadyInMonitoring == false && force == true )
      logger.warn( "node '#{host}' is not in monitoring" )
      logger.warn( "but force delete" )

      annotation = false
    end

    ip    = hostData.dig(:ip)
    short = hostData.dig(:short)
    fqdn  = hostData.dig(:fqdn)

    # read the customized configuration
    #
    config = @database.config( { :ip => ip, :short => host, :fqdn => fqdn } )

#     logger.debug( 'set node status to DELETE' )
    status = @database.setStatus( { :ip => ip, :short => host, :fqdn => fqdn, :status => Storage::MySQL::DELETE } )

    # insert the DNS data into the payload
    #

    payload = Hash.new
    payload = {
      'dns'   => hostData,
      'force' => true
    }

    payload = JSON.generate(payload)

#    logger.debug( sprintf( 'force      : %s', force            ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'discovery  : %s', enableDiscovery  ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'grafana    : %s', enabledGrafana   ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'icinga     : %s', enabledIcinga    ? 'true' : 'false' ) )
#    logger.debug( sprintf( 'annotation : %s', annotation       ? 'true' : 'false' ) )

    if( annotation == true )
      logger.info( 'annotation for remove' )
      self.addAnnotation( host, { 'command' => 'remove', 'argument' => 'node', 'config' => config } )
    end

    if( enabledIcinga == true )
      logger.info( 'remove icinga checks and notifications' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => payload, :prio => 0 } )
    end
    if( enabledGrafana == true )
      logger.info( 'remove grafana dashboards' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => payload, :prio => 0 } )
    end

    if( enableDiscovery == true )
      logger.info( 'remove node from discovery service' )
      self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => payload, :prio => 0, :delay => 5 } )
    end

    @database.removeDNS( { :short => host } )

    result['status']    = 200
    result['message']   = 'the message queue is informed ...'

    return JSON.pretty_generate( result )

  end


  # -- ANNOTATIONS ----------------------------------------------------------------------
  #

  def addAnnotation( host, payload )

    logger.debug( "addAnnotation( #{host}, #{payload} )" )

    status  = 500
    message = 'initialize error'

    result  = Hash.new()
    hash    = Hash.new()

    if( host.size == 0 && payload.size == 0 )

      return JSON.pretty_generate( {
        :status  => 404,
        :message => 'missing arguments for annotations'
      } )
    end

    if( payload.is_a?( String ) )
      payload         = JSON.parse( payload )
    end

    logger.debug( JSON.pretty_generate( payload ) )

    command      = payload.dig('command')
    argument     = payload.dig('argument')
    message      = payload.dig('message')
    description  = payload.dig('description')
    tags         = payload.dig('tags')  || []
    config       = payload.dig('config')

    ip, short, fqdn = self.nsLookup( host )

#    hash         = payload

    if( command == 'create' || command == 'remove' )
#     example:
#     {
#       "command": "create"
#     }
#
#     {
#       "command": "destroy"
#     }

      message     = nil
      description = nil
      tags        = []

      params = {
        :cmd     => command,
        :node    => host,
        :queue   => 'mq-graphite',
        :payload => {
          :timestamp => Time.now().to_i,
          :config    => config,
          :fqdn      => fqdn,
          :node      => host,
          :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
        },
        :prio => 0
      }

      logger.debug(params)

      self.messageQueue(params)

    elsif( command == 'loadtest' && ( argument == 'start' || argument == 'stop' ) )

#     example:
#     {
#       "command": "loadtest",
#       "argument": "start"
#     }
#
#     {
#       "command": "loadtest",
#       "argument": "stop"
#     }

      message     = nil
      description = nil
      tags        = []

      self.messageQueue({
        :cmd     => 'loadtest',
        :node    => host,
        :queue   => 'mq-graphite',
        :payload => {
          :timestamp => Time.now().to_i,
          :config    => config,
          :fqdn      => fqdn,
          :argument  => argument,
          :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
        },
        :prio => 0
      })

    elsif( command == 'deployment' )

#     example:
#     {
#       "command": "deployment",
#       "message": "version 7.1.50",
#       "tags": [
#         "development",
#         "git-0000000"
#       ]
#     }
      description = nil
      self.messageQueue({
        :cmd => 'deployment',
        :node => host,
        :queue => 'mq-graphite',
        :payload => {
          :timestamp => Time.now().to_i,
          :config    => config,
          :fqdn      => fqdn,
          :message   => message,
          :tags      => tags,
          :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
        },
        :prio => 0
      })

    else
#     example:
#     {
#       "command": "",
#       "message": "date: 2016-12-24, last-cristmas",
#       "description": "never so ho-ho-ho",
#       "tags": [
#         "development",
#         "git-0000000"
#       ]
#     }
      self.messageQueue({
        :cmd => 'general',
        :node => host,
        :queue => 'mq-graphite',
        :payload => {
          :timestamp => Time.now().to_i,
          :config    => config,
          :fqdn      => fqdn,
          :message   => message,
          :tags      => tags,
          :description => description,
          :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
        },
        :prio => 0
      })

    end

    status    = 200
    message   = 'annotation succesfull created'

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

