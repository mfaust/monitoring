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

    @logDirectory       = settings[:logDirectory]       ? settings[:logDirectory]       : '/tmp'

    logFile         = sprintf( '%s/monitoring.log', @logDirectory )

    file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync       = true
    @log            = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level      = Logger::INFO
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

    version              = '1.0.1'
    date                 = '2016-10-05'

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


  def addHost( host, force = false )

    experimental = false

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
      discoveryServices = @serviceDiscovery.listHosts( host )

      if( discoveryStatus == 200 || discoveryStatus == 201 )

        if( @enabledIcinga == true )

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


  def removeHost( host, force = false )

    if( host.to_s != '' )

      grafanaResult = 0

      if( @enabledIcinga == true )
        icingaResult    = @icinga.deleteHost( host )
        icingaStatus    = @icinga.status

        status[host.to_s][:icinga] = { :status => icingaStatus   , :message => icingaResult[:message] }
      end

      discoveryResult = @serviceDiscovery.deleteHost( host )
      discoveryStatus = @serviceDiscovery.status

      status[:discovery] = { :status => discoveryStatus, :message => discoveryResult[:message]  }

      if( discoveryStatus == 200 and force == true )

        grafanaResult = @grafana.deleteDashboards( host )

        status[host.to_s][:grafana] = { :status => grafanaResult[:status], :message => grafanaResult[:message] }
      end

      if( @enabledIcinga == true )
        @log.debug( icingaResult )
      end

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


  def listHost( host = nil )

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

        hosts = discoveryResult[:hosts] ? discoveryResult[:hosts] : nil
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
