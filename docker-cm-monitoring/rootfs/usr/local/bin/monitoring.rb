#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.0.1

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/logging'
require_relative '../lib/discover'
require_relative '../lib/grafana'
require_relative '../lib/graphite'
require_relative '../lib/icinga2'
require_relative '../lib/tools'
require_relative '../lib/database'

# -----------------------------------------------------------------------------

class Monitoring

  attr_reader :status, :message, :services

  include Logging

  def initialize( settings = {} )

    @logDirectory  = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'
    @configFile    = '/etc/cm-monitoring.yaml'
    @db = Storage::Database.new()

    self.readConfigFile()

    serviceDiscoverConfig = {
      :logDirectory        => @logDirectory,
      :cacheDirectory      => @cacheDir,
      :jolokiaHost         => @jolokiaHost,
      :jolokiaPort         => @jolokiaPort,
      :scanDiscovery       => @scanDiscovery,
      :serviceConfigFile   => '/etc/cm-service.yaml'
    }

    grafanaConfig = {
      :logDirectory        => @logDirectory,
      :cacheDirectory      => @cacheDir,
      :grafanaHost         => @grafanaHost,
      :grafanaPort         => @grafanaPort,
      :grafanaPath         => @grafanaPath,
      :memcacheHost        => @memcacheHost,
      :memcachePort        => @memcachePort,
      :templateDirectory   => @templateDirectory
    }

    icingaConfig = {
      :logDirectory        => @logDirectory,
      :icingaHost          => @icingaHost,
      :icingaPort          => @icingaPort,
      :icingaApiUser       => @icingaApiUser,
      :icingaApiPass       => @icingaApiPass
    }

    graphiteOptions = {
      :logDirectory        => @logDirectory,
      :graphiteHost        => @graphiteHost,
      :graphiteHttpPort    => @graphiteHttpPort,
      :graphitePort        => @graphitePort,
      :graphitePath        => @graphitePath
    }

    version              = '2.1.0'
    date                 = '2017-01-03'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Monitoring Service' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016 Coremedia' )
    logger.info( '' )
    logger.info( '  enabled Services' )
    logger.info( sprintf( '    - discovery: %s', @enabledDiscovery ) )
    logger.info( sprintf( '    - grafana  : %s', @enabledGrafana ) )
    logger.info( sprintf( '    - icinga2  : %s', @enabledIcinga ) )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

    sleep(2)

    @serviceDiscovery = ServiceDiscovery.new( serviceDiscoverConfig )
    @grafana          = Grafana.new( grafanaConfig )
    @icinga           = Icinga2.new( icingaConfig )
    @graphite         = GraphiteAnnotions::Client.new( graphiteOptions )

  end


  def readConfigFile()

    config = YAML.load_file( @configFile )

    @logDirectory     = config['logDirectory']             ? config['logDirectory']             : '/tmp/log'
    @cacheDir         = config['cacheDirectory']           ? config['cacheDirectory']           : '/tmp/cache'

    @jolokiaHost      = config['jolokia']['host']          ? config['jolokia']['host']          : 'localhost'
    @jolokiaPort      = config['jolokia']['port']          ? config['jolokia']['port']          : 8080

    @grafanaHost      = config['grafana']['host']          ? config['grafana']['host']          : 'localhost'
    @grafanaPort      = config['grafana']['port']          ? config['grafana']['port']          : 3000
    @grafanaPath      = config['grafana']['path']          ? config['grafana']['path']          : nil

    @icingaHost       = config['icinga']['host']           ? config['icinga']['host']           : 'localhost'
    @icingaPort       = config['icinga']['port']           ? config['icinga']['port']           : 5665
    @icingaApiUser    = config['icinga']['api']['user']    ? config['icinga']['api']['user']    : 'icinga'
    @icingaApiPass    = config['icinga']['api']['pass']    ? config['icinga']['api']['pass']    : 'icinga'

    @graphiteHost     = config['graphite']['host']         ? config['graphite']['host']         : 'localhost'
    @graphiteHttpPort = config['graphite']['http-port']    ? config['graphite']['http-port']    : 80
    @graphitePort     = config['graphite']['port']         ? config['graphite']['port']         : 2003
    @graphitePath     = config['graphite']['path']         ? config['graphite']['path']         : nil

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

    if( ip == nil || shortHostName == nil )
      return false
    else
      return hostInfo
    end

  end


  def createCacheDirectory( host )

    directory = sprintf( '%s/%s', @cacheDir, host )

    if( !File.exist?( directory ) )
      Dir.mkdir( directory )
    end

    return directory

  end


  # -- CONFIGURE ------------------------------------------------------------------------
  #
  def writeHostConfiguration( host, payload )

    status       = 500
    message      = 'initialize error'

    current = Hash.new()
    hash    = Hash.new()

    if( host.to_s != '' )

      directory = self.createCacheDirectory( host )

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
  def addHost( host, payload )

    status    = 500
    message   = 'initialize error'

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

      directory       = self.createCacheDirectory( host )

      force           = false
      enableDiscovery = @enabledDiscovery
      enabledGrafana  = @enabledGrafana
      enabledIcinga   = @enabledIcinga
      annotation      = true
      grafanaOverview = true
      services        = []
      tags            = []

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
#        "overview": true
#      }

      logger.debug( payload )

      if( payload != '' )

        hash = JSON.parse( payload )

        logger.debug( hash )

        result[:request] = hash

        force           = hash.keys.include?('force')      ? hash['force']      : false
        enableDiscovery = hash.keys.include?('discovery')  ? hash['discovery']  : @enabledDiscovery
        enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
        enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
        annotation      = hash.keys.include?('annotation') ? hash['annotation'] : true
        grafanaOverview = hash.keys.include?('overview')   ? hash['overview']   : true
        services        = hash.keys.include?('services')   ? hash['services']   : []
        tags            = hash.keys.include?('tags')       ? hash['tags']       : []
      end

      if( force == true )

        logger.info( sprintf( 'remove %s from monitoring', host ) )

        if( enableDiscovery == true )
          discoveryResult  = @serviceDiscovery.deleteHost( host )
          discoveryStatus  = discoveryResult[:status]
          discoveryMessage = discoveryResult[:message]

          logger.debug( "discovery: #{discoveryResult}" )
        end

        if( enabledIcinga == true )
          icingaResult  = @icinga.deleteHost( host )
          icingaStatus  = icingaResult[:status]
          icingaMessage = icingaResult[:message]

          logger.debug( "icinga: #{icingaResult}" )
        end

        if( enabledGrafana == true )
          grafanaResult  = @grafana.deleteDashboards( host )
          grafanaStatus  = grafanaResult[:status]
          grafanaMessage = grafanaResult[:message]

          logger.debug( "grafana: #{grafanaResult}" )
        end

        logger.info( 'done' )

      end

      # TODO
      # change service-discovery to use 'services'

      options = {
        'services'     => services
      }

      discoveryResult   = @serviceDiscovery.addHost( host, options )
      discoveryStatus   = discoveryResult[:status].to_i
      discoveryMessage  = discoveryResult[:message]

      # jolokia is not available (400)
      # Host not available (400)
      # Host already created (409)
      if( discoveryStatus == 400 || discoveryStatus == 409 )

        status  = discoveryStatus
        message = discoveryMessage

        return {
          :status  => status,
          :message => message
        }

      else
        # all fine (200)

        result[host.to_sym] ||= {}

        if( enabledIcinga == true )

          discoverdServices = @serviceDiscovery.listHosts( host )

          services          = discoverdServices.dig( 'hosts', 'services' )

          logger.debug( services )

          services = ( discoverdServices[:hosts] && discoverdServices[:hosts]['services'] ) ? discoverdServices[:hosts]['services'] : nil

          logger.debug( services )

#           services.each do |s|
#             s.last.reject! { |k| k == 'description' }
#             s.last.reject! { |k| k == 'application' }
#           end
#
#           cm = Hash.new()
#           cm = { 'cm' => services }
#
#           icingaResult  = @icinga.addHost( host, cm )
#           icingaStatus  = icingaResult[:status]
#           icingaMessage = icingaResult[:message]

          icingaStatus  = 201
          icingaMessage = 'test message'

          result[host.to_sym][:icinga] ||= {}
          result[host.to_sym][:icinga] = {
            :status     => icingaStatus,
            :message    => icingaMessage
          }

        end

        if( enabledGrafana == true )

          # tags are array or hash ..
          # when hash, we need only the values. the keys are ignoreable
          if( tags.is_a?( Hash ) )
            tags = tags.values
          end

          options = {
            'tags'     => tags,
            'overview' => grafanaOverview
          }

          grafanaResult  = @grafana.addDashbards( host, options )
          grafanaStatus  = grafanaResult[:status]
          grafanaMessage = grafanaResult[:message]

          if( grafanaStatus == 200 )

            grafanaListDashboards = @grafana.listDashboards( host )
            grafanaDashboardCount = grafanaListDashboards[:count]   ? grafanaListDashboards[:count]   : 0

            result[host.to_sym][:grafana] ||= {}
            result[host.to_sym][:grafana] = {
              :status     => grafanaStatus,
              :message    => grafanaMessage,
              :dashboards => grafanaDashboardCount
            }

          end
        end

        if( annotation == true )

          self.addAnnotation( host, { "command": "create", "argument": "node" } )
        end

        result[host.to_sym][:discovery] ||= {}
        result[host.to_sym][:discovery] = {
          :status     => discoveryStatus,
          :message    => discoveryMessage
        }

#        status  = 200
        return result

      end

    end

    return {
      :status  => status,
      :message => message
    }

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


  def removeHost( host, payload )

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

#     example:
#     {
#       "grafana": false,
#       "annotation": true
#     }

      if( payload != '' )

        hash = JSON.parse( payload )

        result[:request] = hash

        enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
        enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
        annotation      = hash.keys.include?('annotation') ? hash['annotation'] : true
      end

      result[host.to_sym] ||= {}

      if( enabledIcinga == true )
        icingaResult  = @icinga.deleteHost( host )
        icingaStatus  = icingaResult[:status]
        icingaMessage = icingaResult[:message]

        logger.debug( "icinga: #{icingaResult}" )

#         icingaStatus  = 201
#         icingaMessage = 'test message'

        result[host.to_sym][:icinga] ||= {}
        result[host.to_sym][:icinga] = {
          :status     => icingaStatus,
          :message    => icingaMessage
        }

      end

      if( enabledGrafana == true )
        grafanaResult  = @grafana.deleteDashboards( host )
        grafanaStatus  = grafanaResult[:status]
        grafanaMessage = grafanaResult[:message]

        logger.debug( "grafana: #{grafanaResult}" )

        result[host.to_sym][:grafana] = {
          :status     => grafanaStatus,
          :message    => grafanaMessage
        }
      end

      discoveryResult  = @serviceDiscovery.deleteHost( host )
      discoveryStatus  = discoveryResult[:status]
      discoveryMessage = discoveryResult[:message]

      logger.debug( "discovery: #{discoveryResult}" )

      if( annotation == true && discoveryStatus == 200 )
        self.addAnnotation( host, { "command": "destroy", "argument": "node" } )
      end

      result[host.to_sym][:discovery] = {
        :status     => discoveryStatus,
        :message    => discoveryMessage
      }

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

        if( command == 'create' || command == 'destroy' )
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
          @graphite.nodeAnnotation( host, command )

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
          @graphite.loadtestAnnotation( host, argument )

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
          @graphite.deploymentAnnotation( host, message, tags )

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
          @graphite.generalAnnotation( host, description, message, tags )
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
