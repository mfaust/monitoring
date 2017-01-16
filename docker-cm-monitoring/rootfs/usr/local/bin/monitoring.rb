#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.0.1

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/logging'
require_relative '../lib/tools'
require_relative '../lib/storage'
require_relative '../lib/message-queue'

# -----------------------------------------------------------------------------

class Monitoring

  attr_reader :status, :message, :services

  include Logging

  def initialize( settings = {} )

    @logDirectory  = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'
    @configFile    = '/etc/cm-monitoring.yaml'

    logger.level           = Logger::DEBUG

    self.readConfigFile()

    @MQSettings = {
      :beanstalkHost       => @mqHost,
      :beanstalkPort       => @mqPort
    }

    version              = '2.2.1'
    date                 = '2017-01-14'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Monitoring Service' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '' )
#     logger.info( '  enabled Services' )
#     logger.info( sprintf( '    - discovery: %s', @enabledDiscovery ) )
#     logger.info( sprintf( '    - grafana  : %s', @enabledGrafana ) )
#     logger.info( sprintf( '    - icinga2  : %s', @enabledIcinga ) )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    @db = Storage::Database.new()

  end


  def readConfigFile()

    config = YAML.load_file( @configFile )

    @logDirectory     = config['logDirectory']             ? config['logDirectory']             : '/tmp/log'
    @cacheDir         = config['cacheDirectory']           ? config['cacheDirectory']           : '/tmp/cache'

    @mqHost           = config['mq']['host']               ? config['mq']['host']               : 'localhost'
    @mqPort           = config['mq']['port']               ? config['mq']['port']               : 11300
    @mqQueue          = config['mq']['queue']              ? config['mq']['queue']              : 'mq-rest-service'

    @templateDirectory = config['grafana']['templateDirectory']  ? config['grafana']['templateDirectory']  : '/var/tmp/templates'

    @memcacheHost     = ENV['MEMCACHE_HOST']               ? ENV['MEMCACHE_HOST']               : nil
    @memcachePort     = ENV['MEMCACHE_PORT']               ? ENV['MEMCACHE_PORT']               : nil

    @serviceChecks    = config['service-checks']           ? config['service-checks']           : nil

    @enabledDiscovery = false
    @enabledGrafana   = false
    @enabledIcinga    = false

    @monitoringServices = config['monitoring-services']    ? config['monitoring-services']      : nil

    if( @monitoringServices != nil )

      services          = @monitoringServices.reduce( :merge )

      @enabledDiscovery = services['discovery'] && services['discovery'] == true  ? true : false
      @enabledGrafana   = services['grafana']   && services['grafana'] == true    ? true : false
      @enabledIcinga    = services['icinga2']   && services['icinga2'] == true    ? true : false
    end

  end


  def checkAvailablility?( host )

    hostInfo      = hostResolve( host )

    ip            = hostInfo[:ip]    ? hostInfo[:ip]    : nil # dnsResolve( host )
    shortHostName = hostInfo[:short] ? hostInfo[:short] : nil # dnsResolve( host )
    longHostName  = hostInfo[:long]  ? hostInfo[:long]  : nil # dnsResolve( host )

    logger.debug( JSON.pretty_generate( hostInfo ) )

    if( ip == nil || shortHostName == nil )
      return false
    else
      return hostInfo
    end

  end


#   def createCacheDirectory( host )
#
#     directory = sprintf( '%s/%s', @cacheDir, host )
#
#     if( !File.exist?( directory ) )
#       Dir.mkdir( directory )
#     end
#
#     return directory
#
#   end


  # -- MESSAGE-QUEUE ---------------------------------------------------------------------
  #
  def messageQueue( params = {} )

#     logger.debug( params )

    command = params.dig(:cmd)
    node    = params.dig(:node)
    queue   = params.dig(:queue)
    data    = params.dig(:payload)
    ttr     = params.dig(:ttr)   || 10
    delay   = params.dig(:delay) || 2

    p = MessageQueue::Producer.new( @MQSettings )

    job = {
      cmd:  command,
      node: node,
      timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ),
      from: 'rest-service',
      payload: data
    }.to_json

    logger.debug( queue )
    logger.debug( job )

    logger.debug( p.addJob( queue, job, ttr, delay ) )

#
# p = MessageQueue::Producer.new( settings )

# #   job = {
# #     cmd:   'add',
# #     payload: sprintf( "foo-bar-%s.com", i )
# #   }.to_json
# #
# #   p.addJob( 'test-tube', job )

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

      if( isIp?( host ) == true )
        @db.createConfig( { :ip => host , :data => hash } )
      else
        shortName = host.split('.').first

        @db.createConfig( { :short => shortName , :data => hash } )
      end

      status  = 200
      message = 'config successful written'

    end

    return {
      :status  => status,
      :message => message
    }

  end


  def getHostConfiguration( host )

    status       = 500
    message      = 'initialize error'

    if( host.to_s != '' )

      if( isIp?( host ) == true )
        data = @db.config( { :ip => host } )
      else
        shortName = host.split('.').first

        data = @db.config( { :short => shortName } )
      end

      if( data != false )
        status = 200
        message = data
      end
    end

    return {
      :status  => status,
      :message => message
    }

  end


  def removeHostConfiguration( host )

    status       = 500
    message      = 'initialize error'

    if( host.to_s != '' )

      if( isIp?( host ) == true )
        data = @db.removeConfig( { :ip => host } )
      else
        shortName = host.split('.').first

        data = @db.removeConfig( { :short => shortName } )
      end

      if( data != false )
        status = 200
        message = 'configuration succesfull removed'
      else
        status  = 404
        message = 'No configuration found'
      end
    end

    return {
      :status  => status,
      :message => message
    }

  end


  # -- HOST -----------------------------------------------------------------------------
  #
#      example:
#      {
#        "force": true,
#        "discovery": false,
#        "icinga": false,
#        "grafana": false,
#        "services": [
#          "cae-live-1": {},
#          "content-managment-server": { "port": 41000 }
#        ],
#        "tags": [
#          "development",
#          "git-0000000"
#        ],
#        "annotation": true,
#        "overview": true,
#        "config": {
#          "ports": [50199],
#          "display-name": "foo.bar.com"
#        }
#      }

  def addHost( host, payload )

    status    = 500
    message   = 'initialize error'

    logger.debug( sprintf( 'addHost( \'%s\', \'%s\' )', host, payload ) )

    logger.info( sprintf( 'add node \'%s\' to monitoring', host ) )

    result    = Hash.new()
    hash      = Hash.new()

    if( host.to_s != '' )

      hostData = self.checkAvailablility?( host )

      if( hostData == false )

        return {
          :status  => 400,
          :message => 'Host are not available (DNS Problem)'
        }

      end

#       directory       = self.createCacheDirectory( host )

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
          logger.debug( 'send message to \'mq-grafana\'' )
          self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => payload } )
        end

        if( enabledIcinga == true )
          logger.info( 'remove icinga checks and notifications' )
          logger.debug( 'send message to \'mq-icinga\'' )
          self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => payload } )
        end

        if( enableDiscovery == true )
          logger.info( 'remove node from discovery service' )
          logger.debug( 'send message to \'mq-discover\'' )
          self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => payload } )
        end

        sleep( 2 )

        logger.info( 'done' )

      end

      # now, we can write an own configiguration per node when we add them, hurray
      if( config.is_a?( Hash) )

        ip    = hostData.dig( :ip )
        short = hostData.dig( :short )

        @db.createConfig( {
          :ip    => ip,
          :short => short,
          :data  => config
        } )

      end

      if( enableDiscovery == true )

        logger.info( 'add node to discovery service' )

        logger.debug( 'send message to \'mq-discover\'' )
        self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-discover', :payload => payload } )
      end

      if( enabledGrafana == true )

        logger.info( 'create grafana dashborads' )

        logger.debug( 'send message to \'mq-grafana\'' )
        self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-grafana', :payload => payload, :ttr => 15, :delay => 10 } )
      end

      if( enabledIcinga == true )

        logger.info( 'create icinga checks and notifications' )

        logger.debug( 'send message to \'mq-icinga\'' )
        self.messageQueue( { :cmd => 'add', :node => host, :queue => 'mq-icinga', :payload => payload, :ttr => 15, :delay => 10 } )
      end

      if( annotation == true )

        logger.info( 'annotation for create' )
        self.addAnnotation( host, { "command": "create", "argument": "node" } )
      end

      discoveryResult = {
        :status  => 200,
        :message => 'send to MQ'
      }

        result[host.to_sym] ||= {}

#       # TODO
#       # change service-discovery to use 'services'
#
#       options = {
#         'services'     => services
#       }

#         if( enabledIcinga == true )
#
#           discoverdServices = @serviceDiscovery.listHosts( host )
#
#           services          = discoverdServices.dig( 'hosts', 'services' )
#
#           logger.debug( services )
#
#           services = ( discoverdServices[:hosts] && discoverdServices[:hosts]['services'] ) ? discoverdServices[:hosts]['services'] : nil
#
#           logger.debug( services )
#
# #           services.each do |s|
# #             s.last.reject! { |k| k == 'description' }
# #             s.last.reject! { |k| k == 'application' }
# #           end
# #
# #           cm = Hash.new()
# #           cm = { 'cm' => services }
# #
# #           icingaResult  = @icinga.addHost( host, cm )
# #           icingaStatus  = icingaResult[:status]
# #           icingaMessage = icingaResult[:message]
#
#           icingaStatus  = 201
#           icingaMessage = 'test message'
#
#           result[host.to_sym][:icinga] ||= {}
#           result[host.to_sym][:icinga] = {
#             :status     => icingaStatus,
#             :message    => icingaMessage
#           }
#
#         end

        result[host.to_sym][:discovery] ||= {}
        result[host.to_sym][:discovery] = discoveryResult

        return result

    end

    return JSON.pretty_generate( {
      :status  => status,
      :message => message
    } )

  end


  def listHost( host = nil, payload = nil )

    status                = 500
    message               = 'initialize error'

    result                = Hash.new()
    hash                  = Hash.new()

    grafanaDashboardCount = 0
    grafanaDashboards     = []

    if( host.to_s != '' )

      result[host.to_s] ||= {}

      hostData = self.checkAvailablility?( host )

      if( hostData == false )
        logger.info( 'host has no DNS Information' )
      end

      result[host.to_s][:dns] ||= {}
      result[host.to_s][:dns] = hostData

      enableDiscovery = @enabledDiscovery
      enabledGrafana  = @enabledGrafana
      enabledIcinga   = @enabledIcinga

#
#       if( payload != nil )
#         payload = payload.dig( 'rack.request.form_vars' )
#       end
#
#       if( payload != nil )
#         enableDiscovery = payload.keys.include?('discovery')  ? payload['discovery']  : @enabledDiscovery
#         enabledGrafana  = payload.keys.include?('grafana')    ? payload['grafana']    : @enabledGrafana
#         enabledIcinga   = payload.keys.include?('icinga')     ? payload['icinga']     : @enabledIcinga
#       end

      logger.debug( ( hostData != false && hostData[:short] ) ? hostData[:short] : host  )

      result[host.to_s] ||= {}

      hostConfiguration        = self.getHostConfiguration( ( hostData != false && hostData[:short] ) ? hostData[:short] : host )
      hostConfigurationStatus  = hostConfiguration[:status]
      hostConfigurationMessage = hostConfiguration[:message]

      if( hostConfigurationStatus == 200 )
        result[host.to_s][:custom_config] = hostConfigurationMessage
      end

      if( enableDiscovery == true )

        discoveryResult  = @serviceDiscovery.listHosts( ( hostData != false && hostData[:short] ) ? hostData[:short] : host )
        discoveryStatus  = discoveryResult[:status]
        discoveryMessage = discoveryResult[:message]

        logger.debug( "discovery: #{discoveryResult}" )

        result[host.to_s][:discovery] ||= {}

        if( discoveryStatus == 200 )

          discoveryServices = nil

          if( discoveryResult.dig( :hosts, host ) != nil )
            discoveryCreated = discoveryResult.dig( :hosts, host, :created ) || 'unknown'
            discoveryOnline  = discoveryResult.dig( :hosts, host, :status )  || 'unknown'
          else
            discoveryCreated = discoveryResult.dig( :hosts, hostData[:short], :created ) || 'unknown'
            discoveryOnline  = discoveryResult.dig( :hosts, hostData[:short], :status )  || 'unknown'
          end

          result[host.to_s][:discovery] = {
            :status     => discoveryStatus,
            :created    => discoveryCreated,
            :online     => discoveryOnline,
            :services   => discoveryServices
          }
        else
          result[host.to_s][:discovery] = {
            :status     => discoveryStatus,
            :message    => discoveryMessage
          }
        end
      end


      if( enabledIcinga == true )

        icingaResult  = @icinga.listHost( ( hostData != false && hostData[:short] ) ? hostData[:short] : host )
        icingaStatus  = icingaResult[:status]
        icingaMessage = icingaResult[:message]

        logger.debug( "icinga: #{icingaResult}" )

        result[host.to_s][:icinga] ||= {}
        result[host.to_s][:icinga] = {
          :status     => icingaStatus,
          :message    => icingaMessage
        }
      end


      if( enabledGrafana == true )
        grafanaResult  = @grafana.listDashboards( ( hostData != false && hostData[:short] ) ? hostData[:short] : host )
        grafanaStatus  = grafanaResult[:status]
        grafanaMessage = grafanaResult[:message]

        logger.debug( "grafana: #{grafanaResult}" )

        result[host.to_s][:grafana] ||= {}

        if( grafanaStatus == 200 )

          grafanaDashboardCount = grafanaResult[:count]      ? grafanaResult[:count]      : 0
          grafanaDashboards     = grafanaResult[:dashboards] ? grafanaResult[:dashboards] : []

          result[host.to_s][:grafana] = {
            :status     => grafanaStatus,
            :dashboards => grafanaDashboards,
            :count      => grafanaDashboardCount
          }
        else

          result[host.to_s][:grafana] = {
            :status     => grafanaStatus,
            :message    => grafanaMessage
          }

        end
      end


      return result

    else

      discoveryResult  = @serviceDiscovery.listHosts( host )
      discoveryStatus  = discoveryResult[:status]
      discoveryMessage = discoveryResult[:message]


      if( discoveryStatus != 400 )

        array = Array.new()

        hosts = discoveryResult[:hosts] ? discoveryResult[:hosts] : []

        if( hosts.count != 0 )

          hosts = hosts.reduce( :merge ).keys

          hosts.each do |h|

            r  = @serviceDiscovery.listHosts( h )
            s  = r[:status] ? r[:status] : 400

            if( s != 400 )

              dHost        = r[:hosts] ? r[:hosts] : nil

              if( dHost != nil )
                discoveryCreated      = dHost[h][:created] ? dHost[h][:created] : 'unknown'
                discoveryOnline       = dHost[h][:status]  ? dHost[h][:status]  : 'unknown'
              end
            end

            hash  = {
              h.to_s => { :discovery => { :status => s, :created => discoveryCreated, :online => discoveryOnline } }
            }

            array.push( hash )

          end

          discoveryResult = array.reduce( :merge )
        end
      end

      return discoveryResult

    end

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

    result    = Hash.new()
    hash      = Hash.new()

    if( host.to_s != '' )

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
        logger.debug( 'send message to \'mq-icinga\'' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-icinga', :payload => { "force" => true } } )
      end
      if( enabledGrafana == true )
        logger.info( 'remove grafana dashborads' )
        logger.debug( 'send message to \'mq-grafana\'' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-grafana', :payload => { "force" => true } } )
      end

      if( enableDiscovery == true )
        logger.info( 'remove node from discovery service' )
        logger.debug( 'send message to \'mq-discover\'' )
        self.messageQueue( { :cmd => 'remove', :node => host, :queue => 'mq-discover', :payload => { "force" => true } } )
      end

      if( force == true )
        logger.info( 'remove configuration from db (force mode)' )
        @db.removeConfig( { :ip => host, :short => host } )
      end

      discoveryResult = {
        :status  => 200,
        :message => 'send to MQ'
      }

      result[host.to_sym][:discovery] = discoveryResult

      return result
    end

    return {
      :status  => status,
      :message => message
    }


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

        hash = payload

        result[:request] = hash

        command      = hash[:command]     ? hash[:command]     : nil
        argument     = hash[:argument]    ? hash[:argument]    : nil
        message      = hash[:message]     ? hash[:message]     : nil
        description  = hash[:description] ? hash[:description] : nil
        tags         = hash[:tags]        ? hash[:tags]        : []

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

#           @graphite.nodeAnnotation( host, command )

        elsif( command == 'loadtest' && ( argument == 'start' || stop == 'stop' ) )

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

          # @graphite.loadtestAnnotation( host, argument )

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

#           @graphite.deploymentAnnotation( host, message, tags )

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

#           @graphite.generalAnnotation( host, description, message, tags )
        end

        status    = 200
        message   = 'annotation succesfull created'
      else

        status    = 400
        message   = 'annotation data not set'

      end

    end

    return {
      :status  => status,
      :message => message
    }

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
