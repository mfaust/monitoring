#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.x.x

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/discover'
require_relative '../lib/grafana'
require_relative '../lib/graphite'
require_relative '../lib/icinga2'
require_relative '../lib/tools'

# -----------------------------------------------------------------------------

class Monitoring

  attr_reader :status, :message, :services

  def initialize( settings = {} )

    @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'

    logFile         = sprintf( '%s/monitoring.log', @logDirectory )

    file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync       = true
    @log            = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level      = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter  = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @configFile = '/etc/cm-monitoring.yaml'

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

    version              = '1.9.12'
    date                 = '2016-11-24'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CoreMedia - Monitoring Service' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( '' )
    @log.info( '  enabled Services' )
    @log.info( sprintf( '    - discovery: %s', @enabledDiscovery ) )
    @log.info( sprintf( '    - grafana  : %s', @enabledGrafana ) )
    @log.info( sprintf( '    - icinga2  : %s', @enabledIcinga ) )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

    sleep(2)

    @serviceDiscovery = ServiceDiscovery.new( serviceDiscoverConfig )
    @grafana          = Grafana.new( grafanaConfig )

    if( @enabledIcinga == true )
      @icinga           = Icinga2.new( icingaConfig )
    end

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

    hostInfo = hostResolve( host )

    ip            = hostInfo[:ip]    ? hostInfo[:ip]    : nil # dnsResolve( host )
    shortHostName = hostInfo[:short] ? hostInfo[:short] : nil # dnsResolve( host )
    longHostName  = hostInfo[:long]  ? hostInfo[:long]  : nil # dnsResolve( host )

    @log.info( sprintf( 'Host      : %s', host ) )
    @log.info( sprintf( 'IP        : %s', ip ) )
    @log.info( sprintf( 'short Name: %s', shortHostName ) )
    @log.info( sprintf( 'long Name : %s', longHostName ) )

    if( ip == nil || shortHostName == nil )
      return false
    else
      return true
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

      localConfig = sprintf( '%s/config.json', directory )

      if( File.exist?( localConfig ) == true )

        data    = File.read( localConfig )
        current = JSON.parse( data )

      end

      hash = current.merge( hash )

      File.open( localConfig , 'w' ) { |f| f.write( JSON.pretty_generate( hash ) ) }

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

      directory   = sprintf( '%s/%s', @cacheDir, host )
      localConfig = sprintf( '%s/config.json', directory )

      if( File.exist?( localConfig ) == true )

        data    = File.read( localConfig )
        current = JSON.parse( data )

        status  = 200
        message = current
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


  def removeHostConfiguration( host )

    status       = 500
    message      = 'initialize error'

    if( host.to_s != '' )

      directory   = sprintf( '%s/%s', @cacheDir, host )
      localConfig = sprintf( '%s/config.json', directory )

      if( File.exist?( localConfig ) == true )

        FileUtils.rm( localConfig, :force => true )

        status  = 200
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

      if( self.checkAvailablility?( host ) == false )

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
      annotation      = false
      grafanaOverview = false
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

      if( payload != '' )

        hash = JSON.parse( payload )

        result[:request] = hash

        force           = hash.keys.include?('force')      ? hash['force']      : false
        enableDiscovery = hash.keys.include?('discovery')  ? hash['discovery']  : @enabledDiscovery
        enabledGrafana  = hash.keys.include?('grafana')    ? hash['grafana']    : @enabledGrafana
        enabledIcinga   = hash.keys.include?('icinga')     ? hash['icinga']     : @enabledIcinga
        annotation      = hash.keys.include?('annotation') ? hash['annotation'] : false
        grafanaOverview = hash.keys.include?('overview')   ? hash['overview']   : false
        services        = hash['services']  ? hash['services']  : []
        tags            = hash['tags']      ? hash['tags']      : []
      end

      if( force == true )

        @log.info( sprintf( 'remove %s from monitoring', host ) )

        if( enableDiscovery == true )
          discoveryResult  = @serviceDiscovery.deleteHost( host )
          discoveryStatus  = discoveryResult[:status]
          discoveryMessage = discoveryResult[:message]

          @log.debug( "discovery: #{discoveryResult}" )
        end

        if( enabledIcinga == true )
          icingaResult  = @icinga.deleteHost( host )
          icingaStatus  = icingaResult[:status]
          icingaMessage = icingaResult[:message]

          @log.debug( "icinga: #{icingaResult}" )
        end

        if( enabledGrafana == true )
          grafanaResult  = @grafana.deleteDashboards( host, tags )
          grafanaStatus  = grafanaResult[:status]
          grafanaMessage = grafanaResult[:message]

          @log.debug( "grafana: #{grafanaResult}" )
        end

        @log.info( 'done' )

      end

      # TODO
      # change service-discovery to use 'services'

      discoveryResult   = @serviceDiscovery.addHost( host )
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

          @log.debug( services )

          services = ( discoverdServices[:hosts] && discoverdServices[:hosts]['services'] ) ? discoverdServices[:hosts]['services'] : nil

          @log.debug( services )

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

          grafanaResult  = @grafana.addDashbards( host )
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

      enableDiscovery = @enabledDiscovery
      enabledGrafana  = @enabledGrafana
      enabledIcinga   = @enabledIcinga

      payload = payload.dig( 'rack.request.form_vars' )

      if( payload != nil )
        enableDiscovery = payload.keys.include?('discovery')  ? payload['discovery']  : @enabledDiscovery
        enabledGrafana  = payload.keys.include?('grafana')    ? payload['grafana']    : @enabledGrafana
        enabledIcinga   = payload.keys.include?('icinga')     ? payload['icinga']     : @enabledIcinga
      end

      result[host.to_sym] ||= {}

      hostConfiguration        = self.getHostConfiguration( host )
      hostConfigurationStatus  = hostConfiguration[:status]
      hostConfigurationMessage = hostConfiguration[:message]

      if( hostConfigurationStatus == 200 )
        result[host.to_sym][:custom_config] = hostConfigurationMessage
      end

      if( enableDiscovery == true )
        discoveryResult  = @serviceDiscovery.listHosts( host )
        discoveryStatus  = discoveryResult[:status]
        discoveryMessage = discoveryResult[:message]

        @log.debug( "discovery: #{discoveryResult}" )

        result[host.to_sym][:discovery] ||= {}

        if( discoveryStatus == 200 )

          discoverHost     = discoveryResult[:hosts]      ? discoveryResult[:hosts]      : nil
          discoveryCreated = discoverHost[host][:created] ? discoverHost[host][:created] : 'unknown'
          discoveryOnline  = discoverHost[host][:status]  ? discoverHost[host][:status]  : 'unknown'

          result[host.to_sym][:discovery] = {
            :status     => discoveryStatus,
            :created    => discoveryCreated,
            :online     => discoveryOnline
          }
        else
          result[host.to_sym][:discovery] = {
            :status     => discoveryStatus,
            :message    => discoveryMessage
          }
        end
      end


      if( enabledIcinga == true )
        icingaResult  = @icinga.listHost( host )
        icingaStatus  = icingaResult[:status]
        icingaMessage = icingaResult[:message]

        @log.debug( "icinga: #{icingaResult}" )

        result[host.to_sym][:icinga] ||= {}
        result[host.to_sym][:icinga] = {
          :status     => icingaStatus,
          :message    => icingaMessage
        }
      end


      if( enabledGrafana == true )
        grafanaResult  = @grafana.listDashboards( host )
        grafanaStatus  = grafanaResult[:status]
        grafanaMessage = grafanaResult[:message]

        @log.debug( "grafana: #{grafanaResult}" )

        result[host.to_sym][:grafana] ||= {}

        if( grafanaStatus == 200 )
          grafanaDashboardCount = grafanaResult[:count]      ? grafanaResult[:count]      : 0
          grafanaDashboards     = grafanaResult[:dashboards] ? grafanaResult[:dashboards] : []

          result[host.to_sym][:grafana] = {
            :status     => grafanaStatus,
            :dashboards => grafanaDashboards,
            :count      => grafanaDashboardCount
          }
        else

          result[host.to_sym][:grafana] = {
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

      directory = self.createCacheDirectory( host )

      enabledGrafana  = @enabledGrafana
      enabledIcinga   = @enabledIcinga
      annotation      = false

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
        annotation      = hash.keys.include?('annotation') ? hash['annotation'] : false
      end

      @log.info( sprintf( 'remove %s from monitoring', host ) )

      result[host.to_sym] ||= {}

      if( enabledIcinga == true )
        icingaResult  = @icinga.deleteHost( host )
        icingaStatus  = icingaResult[:status]
        icingaMessage = icingaResult[:message]

        @log.debug( "icinga: #{icingaResult}" )

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

        @log.debug( "grafana: #{grafanaResult}" )

        result[host.to_sym][:grafana] = {
          :status     => grafanaStatus,
          :message    => grafanaMessage
        }
      end

      discoveryResult  = @serviceDiscovery.deleteHost( host )
      discoveryStatus  = discoveryResult[:status]
      discoveryMessage = discoveryResult[:message]

      @log.debug( "discovery: #{discoveryResult}" )

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

        hash = JSON.parse( payload )

        result[:request] = hash

        command      = hash.keys.include?('command')     ? hash['command']     : nil
        argument     = hash.keys.include?('argument')    ? hash['argument']    : nil
        message      = hash.keys.include?('message')     ? hash['message']     : nil
        description  = hash.keys.include?('description') ? hash['description'] : nil
        tags         = hash['tags']                      ? hash['tags']        : []

        if( argument == 'node' && ( command == 'create' || command == 'destroy' ) )
#         example:
#         {
#           "command": "create",
#           "argument": "node"
#         }
#
#         {
#           "command": "destroy",
#           "argument": "node"
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





  def addHostV1( host, force = false )

    experimental = false

    status       = 500
    message      = 'initialize error'

    if( host.to_s != '' )

      if( force == true )

        @log.info( sprintf( 'remove %s from monitoring', host ) )

        if( @enabledIcinga == true )
          icingaResult = @icinga.deleteHost( host )
          icingaStatus = @icinga.status
        end

        grafanaResult = @grafana.deleteDashboards( host )
        grafanaStatus = @grafana.status

        discoveryResult   = @serviceDiscovery.deleteHost( host )
        discoveryStatus   = @serviceDiscovery.status

        if( @enabledIcinga == true )
          @log.debug( icingaResult )
        end

        @log.debug( grafanaResult )
        @log.debug( discoveryResult )

        @log.info( 'done' )

      end

      discoveryResult   = @serviceDiscovery.addHost( host )
      discoveryStatus   = @serviceDiscovery.status

      if( discoveryResult[:status].to_i == 200 || discoveryResult[:status].to_i == 201 )

        if( @enabledIcinga == true )

          discoveryServices = @serviceDiscovery.listHosts( host )

          services = ( discoveryServices[:hosts] && discoveryServices[:hosts]['services'] ) ? discoveryServices[:hosts]['services'] : nil

          services.each do |s|
            s.last.reject! { |k| k == 'description' }
            s.last.reject! { |k| k == 'application' }
          end

          cm = Hash.new()
          cm = { 'cm' => services }

          icingaResult = @icinga.addHost( host, cm )
          icingaStatus = @icinga.status

          if( icingaStatus == 200 && experimental == true )

            hash  = Hash.new()
            array = Array.new()

            # add some custom service-checks
            @serviceChecks.each do |type,s|

              count = 0

              s.each do |v|

                proto = v['proto'] ? v['proto']  : 'http'
                vhost = v['vhost'] ? v['vhost']  : nil
                port  = v['port']  ? v['port']   : 80
                url   = v['url']   ? v['url']    : '/'

                if( type == 'ssl' || type == 'ssl_cert' )
                  proto = 'https'
                  port  = 443
                end

                if( proto == 'https' && ( port == nil || port == 80 ) )
                  port = 443
                end

                if( vhost =~ /.*%HOST%$/ )
                  #
                  fqdn = Socket.gethostbyname( host ).first
                  fqdn = vhost.gsub( '%HOST%', fqdn )
                else
                  vhost.gsub!( '%HOST%', host )
                  fqdn  = Socket.gethostbyname( vhost ).first
                end

                hashKey      = sprintf( '%s-%s-%d', type.downcase, fqdn.downcase, count += 1 )
                displayName  = sprintf( '%s - %s' , type.upcase  , fqdn.downcase )

                if( type == 'http' || type == 'https' )

                  # simple HTTP Check
                  hash = {
                    hashKey => {
                      'display_name'    => displayName,
                      'check_command'   => type.downcase,
                      'host_name'       => host,
                      'vars.http_vhost' => fqdn,
                      'vars.http_uri'   => url,
                      'vars.http_port'  => port
                    }
                  }

                  if( port == 443 )
                    hash[hashKey.to_s]['vars.http_ssl'] = true
                    hash[hashKey.to_s]['vars.http_ssl_force_tlsv1_2'] = true
                  end

                elsif( type == 'ssl' )

                  # check for a ssl certificate
                  hash = {
                    hashKey => {
                      'display_name'                      => displayName,
                      'check_command'                     => type.downcase,
                      'host_name'                         => host,
                      'vars.ssl_address'                  => fqdn,
                      'vars.ssl_port'                     => port,
                      'vars.ssl_timeout'                  => 10,
                      'vars.ssl_cert_valid_days_warn'     => 30,
                      'vars.ssl_cert_valid_days_critical' => 10
                    }
                  }

                end

                array.push( hash )
              end
            end

            services = array.reduce( :merge )

            @icinga.addServices( host, services )

          end
        end

        grafanaResult = @grafana.addDashbards( host )
        grafanaStatus = @grafana.status

        status  = 200
        message = 'host successfuly added'

      elsif( discoveryResult[:status].to_i == 409 )

        status  = discoveryResult[:status].to_i
        message = discoveryResult[:message] ? discoveryResult[:message] : 'Host already created'
      end

    else

      status  = 400
      message = 'need hostname to add to monitoring'

    end

    return {
      :status  => status,
      :message => message
    }

  end


  def removeHostV1( host, force = false )

    if( host.to_s != '' )

      grafanaResult = 0
      result        = Array.new()

      discoveryResult = @serviceDiscovery.deleteHost( host )

      discoveryHash = { :discovery => { :status => discoveryResult[:status], :message => discoveryResult[:message]  } }

      result.push( discoveryHash )

      if( discoveryResult[:status].to_i == 200 and force == true )

        grafanaResult = @grafana.deleteDashboards( host )

        grafanaHash = { :grafana => { :status => grafanaResult[:status], :message => grafanaResult[:message] } }

        result.push( grafanaHash )
      end

      if( @enabledIcinga == true )

        icingaResult    = @icinga.deleteHost( host )
        icingaStatus    = @icinga.status

        icingaHash = { :icinga => { :status => icingaStatus   , :message => icingaResult[:message] } }

        result.push( grafanaHash )

        @log.debug( icingaHash )
      end

      discoveryResult = result.reduce( :merge )

      return {
        :status    => 200,
        :message   => discoveryResult
      }

    else

      return {
        :status  => 400,
        :message => 'need hostname to remove from monitoring'
      }
    end

  end


  def listHostV1( host = nil )

    if( host.to_s != '' )

      icingaStatus = 0

      if( @enabledIcinga == true )
        icingaResult    = @icinga.listHost( host )
      end

      grafanaResult   = @grafana.listDashboards( host )
      discoveryResult = @serviceDiscovery.listHosts( host )

      grafanaDashboardCount = 0
      discoveryCreated      = 'unknown'
      discoveryOnline       = 'unknown'

      if( @enabledIcinga == true )
        icingaStatus          = icingaResult[:status]    ? icingaResult[:status]    : 400
      end

      grafanaStatus         = grafanaResult[:status]   ? grafanaResult[:status]   : 400

      if( grafanaStatus != 400 )
        grafanaDashboardCount = grafanaResult[:count]   ? grafanaResult[:count]   : 0
      end

      if( grafanaStatus != 500 )
        # TODO
        # implement it
        grafanaMessage        = grafanaResult[:message]   ? grafanaResult[:message]   : 'internal server error'
      end

      discoveryStatus       = discoveryResult[:status] ? discoveryResult[:status] : 400

      if( discoveryStatus != 400 )

        discoverHost        = discoveryResult[:hosts] ? discoveryResult[:hosts] : nil

        if( discoverHost != nil )
          discoveryCreated      = discoverHost[host][:created] ? discoverHost[host][:created] : 'unknown'
          discoveryOnline       = discoverHost[host][:status]  ? discoverHost[host][:status]  : 'unknown'
        end

      end

      return {
        host.to_s => {
          :icinga    => { :status => icingaStatus },
          :grafana   => { :status => grafanaStatus, :count => grafanaDashboardCount },
          :discovery => { :status => discoveryStatus, :created => discoveryCreated, :online => discoveryOnline }
        }
      }

    else

      discoveryResult   = @serviceDiscovery.listHosts()
      discoveryStatus   = discoveryResult[:status] ? discoveryResult[:status] : 400

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

      return {
        :status    => 200,
        :discovery => discoveryResult
      }

    end

  end


  def addGrafanaGroupOverview( hosts, force = false )

    grafanaResult = @grafana.addGroupOverview( hosts, force )
#    grafanaStatus = grafanaResult[:status]

    return {
      :status  => grafanaResult[:status],
      :message => grafanaResult[:message]
    }

  end


  def addAnnotationV1( host, type, descr = '', message = '', customTags = [] )

    case type
    when 'create'
      @graphite.nodeAnnotation( host, type )
    when 'destroy'
      @graphite.nodeAnnotation( host, type )
    when 'start'
      @graphite.loadtestAnnotation( host, type )
    when 'stop'
      @graphite.loadtestAnnotation( host, type )
    when 'deployment'
      @graphite.deploymentAnnotation( host, message )
    else
      @graphite.generalAnnotation( host, descr, message, customTags )
    end

  end



end

# ------------------------------------------------------------------------------------------

# options = {
#  :logDirectory => @logDir
# }
#
# m = Monitoring.new( options )
#
# puts m.listHost( 'monitoring-16-01' )
#
# m.addAnnotation( 'monitoring-16-01', 'create' )
# # puts m.removeHost( 'monitoring-16-01' )
# puts m.addHost( 'monitoring-16-01' , true )
# # puts m.removeHost( 'blueprint-box' )
#
#
# puts m.listHost( 'monitoring-16-01' )

# EOF
