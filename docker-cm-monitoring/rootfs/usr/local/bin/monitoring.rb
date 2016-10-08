#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v1.0.1

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

    @logDirectory      = settings[:logDirectory] ? settings[:logDirectory] : '/tmp'

    logFile = sprintf( '%s/monitoring.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @configFile = '/etc/cm-monitoring.yaml'

    self.readConfigFile()

    serviceDiscoverConfig = {
      'log_dir'            => @logDirectory,
      'cache_dir'          => @cacheDir,
      'jolokia_host'       => @jolokia_host,
      'jolokia_port'       => @jolokia_port,
      'scanDiscovery'      => @scanDiscovery,
      'serviceConfigFile'  => '/etc/cm-service.json'
    }

    grafanaConfig = {
      'log_dir'            => @logDirectory,
      'cache_dir'          => @cacheDir,
      'grafana_host'       => @grafana_host,
      'grafana_port'       => @grafana_port,
      'grafana_path'       => @grafana_path,
      'memcacheHost'       => @memcacheHost,
      'memcachePort'       => @memcachePort,
      'template_dir'       => @template_dir
    }

    icingaConfig = {
      'logDirectory'       => @logDirectory,
      'icingaHost'         => @icingaHost,
      'icingaPort'         => @icingaPort,
      'icingaApiUser'      => @icingaApiUser,
      'icingaApiPass'      => @icingaApiPass
    }

    graphiteOptions = {
      'logDirectory'       => @logDirectory,
      'graphiteHost'       => @graphiteHost,
      'graphiteHttpPort'   => @graphiteHttpPort,
      'graphitePort'       => @graphitePort,
      'graphitePath'       => @graphitePath,
      'memcacheHost'       => @memcacheHost,
      'memcachePort'       => @memcachePort
    }

    version              = '1.0.1'
    date                 = '2016-10-05'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CoreMedia - Monitoring Service' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

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

    @jolokia_host     = config['jolokia']['host']          ? config['jolokia']['host']          : 'localhost'
    @jolokia_port     = config['jolokia']['port']          ? config['jolokia']['port']          : 8080

    @grafana_host     = config['grafana']['host']          ? config['grafana']['host']          : 'localhost'
    @grafana_port     = config['grafana']['port']          ? config['grafana']['port']          : 3000
    @grafana_path     = config['grafana']['path']          ? config['grafana']['path']          : nil

    @icingaHost       = config['icinga']['host']           ? config['icinga']['host']           : 'localhost'
    @icingaPort       = config['icinga']['port']           ? config['icinga']['port']           : 5665
    @icingaApiUser    = config['icinga']['api']['user']    ? config['icinga']['api']['user']    : 'icinga'
    @icingaApiPass    = config['icinga']['api']['pass']    ? config['icinga']['api']['pass']    : 'icinga'

    @graphiteHost     = config['graphite']['host']         ? config['graphite']['host']         : 'localhost'
    @graphiteHttpPort = config['graphite']['http-port']    ? config['graphite']['http-port']    : 80
    @graphitePort     = config['graphite']['port']         ? config['graphite']['port']         : 2003
    @graphitePath     = config['graphite']['path']         ? config['graphite']['path']         : nil

    @template_dir     = config['grafana']['templateDirectory']  ? config['grafana']['templateDirectory']  : '/var/tmp/templates'

    @memcacheHost     = ENV['MEMCACHE_HOST']               ? ENV['MEMCACHE_HOST']               : nil
    @memcachePort     = ENV['MEMCACHE_PORT']               ? ENV['MEMCACHE_PORT']               : nil

    @serviceChecks    = config['service-checks']           ? config['service-checks']           : nil

  end


  def addHost( host, force = false )

    if( host.to_s != '' )

      if( force == true )

        @log.info( sprintf( 'remove %s from monitoring', host ) )

        icingaResult = @icinga.deleteHost( host )
        icingaStatus = @icinga.status

        grafanaResult = @grafana.deleteDashboards( host )
        grafanaStatus = @grafana.status

        discoveryResult   = @serviceDiscovery.deleteHost( host )
        discoveryStatus   = @serviceDiscovery.status

        @log.debug( icingaResult )
        @log.debug( grafanaResult )
        @log.debug( discoveryResult )

        @log.info( 'done' )

      end

      discoveryResult   = @serviceDiscovery.addHost( host )
      discoveryStatus   = @serviceDiscovery.status
      discoveryServices = @serviceDiscovery.listHosts( host )

      if( discoveryStatus == 200 || discoveryStatus == 201 )

        services = ( discoveryServices[:hosts] && discoveryServices[:hosts]['services'] ) ? discoveryServices[:hosts]['services'] : nil

        services.each do |s|
          s.last.reject! { |k| k == 'description' }
          s.last.reject! { |k| k == 'application' }
        end

        cm = Hash.new()
        cm = { 'cm' => services }

        icingaResult = @icinga.addHost( host, cm )
        icingaStatus = @icinga.status

        if( icingaStatus == 200 )

          hash  = Hash.new()
          array = Array.new()

          @serviceChecks.each do |type|

            @log.debug( type )

            type.each do |subtype,v|

              @log.debug( subtype )
              @log.debug( v )

              hash = {
                sprintf( '%s-', type.lowercase ) => {
                  'display_name'    => sprintf( '%s - %s', type.uppercase, host ),
                  'check_command'   => type.lowercase,
                  'host_name'       => host,
                  'vars.http_vhost' => host,
                  'vars.http_uri'   => sprintf( v, host )
                }
              }

              array.push( hash )
            end
          end

          @log.debug( array )

          # add some custom checks
          services = {
            'http-preview-helios-DE' => {
              'display_name'       => sprintf( 'Preview - %s', host ),
              'check_command'      => 'http',
              'host_name'          => host,
              'vars.http_vhost'    => host,
              'vars.http_uri'      => sprintf( 'https://preview-helios.%s.coremedia.vm/perfectchef-de-de', host ) ,
              'vars.http_ssl'      => true
            },
            'http-shop-preview-production-helios' => {
              'display_name'       => sprintf( 'Preview - Auroa eSite', host ),
              'check_command'      => 'http',
              'host_name'          => host,
              'vars.http_vhost'    => host,
              'vars.http_uri'      => sprintf( 'http://shop-preview-production-helios.%s.coremedia.vm/webapp/wcs/stores/servlet/en/auroraesite', host ) ,
              'vars.http_ssl'      => true
            },
            'http-live-helios-DE' => {
              'display_name'       => sprintf( 'Live - %s ', host ),
              'check_command'      => 'http',
              'host_name'          => host,
              'vars.http_vhost'    => host,
              'vars.http_uri'      => sprintf( 'https://helios.%s.coremedia.vm/perfectchef-de-de', host ) ,
              'vars.http_ssl'      => true
            },
            'http-shop-helios' => {
              'display_name'       => sprintf( 'Live - Auroa eSite', host ),
              'check_command'      => 'http',
              'host_name'          => host,
              'vars.http_vhost'    => host,
              'vars.http_uri'      => sprintf( 'http://shop-helios.%s.coremedia.vm/webapp/wcs/stores/servlet/en/auroraesite', host ) ,
              'vars.http_ssl'      => true
            },
            'http-studio' => {
              'display_name'       => sprintf( 'Live - Studio', host ),
              'check_command'      => 'http',
              'host_name'          => host,
              'vars.http_vhost'    => host,
              'vars.http_uri'      => sprintf( 'http://studio.%s.coremedia.vm/', host ) ,
              'vars.http_ssl'      => true
            }
          }

          @log.debug( service )

#          @icinga.addServices( host, services )

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


  def removeHost( host, force = false )

    if( host.to_s != '' )

      grafanaResult = 0

      icingaResult    = @icinga.deleteHost( host )
      icingaStatus    = @icinga.status

      discoveryResult = @serviceDiscovery.deleteHost( host )
      discoveryStatus = @serviceDiscovery.status

      status = {
        host.to_s => {
          :icinga    => { :status => icingaStatus   , :message => icingaResult[:message] },
          :discovery => { :status => discoveryStatus, :message => discoveryResult[:message]  }
        }
      }

      if( discoveryStatus == 200 and force == true )
        grafanaResult = @grafana.deleteDashboards( host )

        status[host.to_s][:grafana] = { :status => grafanaResult[:status], :message => grafanaResult[:message] }
      end

      @log.debug( icingaResult )
      @log.debug( discoveryResult )
      @log.debug( grafanaResult )

      return status

    else

      return {
        :status  => 400,
        :message => 'need hostname to remove from monitoring'
      }
    end

  end


  def listHost( host )

    if( host.to_s != '' )

      icingaResult    = @icinga.listHost( host )
      grafanaResult   = @grafana.listDashboards( host )
      discoveryResult = @serviceDiscovery.listHosts( host )

      grafanaDashboardCount = 0
      discoveryCreated      = 'unknown'
      discoveryOnline       = 'unknown'

      icingaStatus          = icingaResult[:status]    ? icingaResult[:status]    : 400

      grafanaStatus         = grafanaResult[:status]   ? grafanaResult[:status]   : 400

      if( grafanaStatus != 400 )
        grafanaDashboardCount = grafanaResult[:count]   ? grafanaResult[:count]   : 0
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

      return {
        :status  => 400,
        :message => 'need hostname to list entries from monitoring'
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


  def addAnnotation( host, type, descr = '', message = '', customTags = [] )

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
