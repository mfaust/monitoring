#!/usr/bin/ruby
#
# 14.09.2016 - Bodo Schulz
#
#
# v0.0.3

# -----------------------------------------------------------------------------

require 'yaml'

require_relative '../lib/discover'
require_relative '../lib/grafana'
require_relative '../lib/graphite'
require_relative '../lib/icinga2'
require_relative '../lib/tools'

configFile = '/etc/cm-monitoring.yaml'

if( File.exist?( configFile ) )

  config = YAML.load_file( configFile )

  @logDir    = config['monitoring']['log_dir'] ? config['monitoring']['log_dir'] : '/tmp/log'

else
  puts "no configuration exists"
  exit 1
end

# -----------------------------------------------------------------------------

class Monitoring

  attr_reader :status, :message, :services

  def initialize( settings = {} )

    logFile = sprintf( '%s/monitoring.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
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
      'log_dir'      => @logDirectory,
      'cache_dir'    => @cacheDir,
      'grafana_host' => @grafana_host,
      'grafana_port' => @grafana_port,
      'grafana_path' => @grafana_path,
      'template_dir' => @template_dir
    }

    icingaConfig = {
      'logDirectory'  => @logDirectory,
      'icingaHost'    => @icingaHost,
      'icingaPort'    => @icingaPort,
      'icingaApiUser' => @icingaApiUser,
      'icingaApiPass' => @icingaApiPass
    }

    graphiteOptions = {
      'logDirectory'          => @logDirectory,
      'graphiteHost'          => @graphiteHost,
      'graphiteHttpPort'      => @graphiteHttpPort,
      'graphitePort'          => @graphitePort
    }

    @serviceDiscovery = ServiceDiscovery.new( serviceDiscoverConfig )
    @grafana          = Grafana.new( grafanaConfig )
    @icinga           = Icinga2.new( icingaConfig )
    @graphite         = GraphiteAnnotions::Client.new( graphiteOptions )

  end


  def readConfigFile()

    config = YAML.load_file( @configFile )

    @logDirectory     = config['monitoring']['log_dir']                 ? config['monitoring']['log_dir']                  : '/tmp/log'
    @cacheDir         = config['monitoring']['cache_dir']               ? config['monitoring']['cache_dir']                : '/tmp/cache'

    @jolokia_host     = config['monitoring']['jolokia']['host']         ? config['monitoring']['jolokia']['host']          : 'localhost'
    @jolokia_port     = config['monitoring']['jolokia']['port']         ? config['monitoring']['jolokia']['port']          : 8080

    @grafana_host     = config['monitoring']['grafana']['host']         ? config['monitoring']['grafana']['host']          : 'localhost'
    @grafana_port     = config['monitoring']['grafana']['port']         ? config['monitoring']['grafana']['port']          : 3000
    @grafana_path     = config['monitoring']['grafana']['path']         ? config['monitoring']['grafana']['path']          : nil

    @icingaHost       = config['monitoring']['icinga']['host']          ? config['monitoring']['icinga']['host']           : 'localhost'
    @icingaPort       = config['monitoring']['icinga']['port']          ? config['monitoring']['icinga']['port']           : 5665
    @icingaApiUser    = config['monitoring']['icinga']['api']['user']   ? config['monitoring']['icinga']['api']['user']    : 'icinga'
    @icingaApiPass    = config['monitoring']['icinga']['api']['pass']   ? config['monitoring']['icinga']['api']['pass']    : 'icinga'

    @template_dir     = config['monitoring']['grafana']['template_dir'] ? config['monitoring']['grafana']['template_dir']  : '/var/tmp/templates'

  end


  def addHost( host, force = false )

    if( host.to_s != '' )

      discoveryResult   = @serviceDiscovery.addHost( host, [], force )
      discoveryStatus   = @serviceDiscovery.status
      discoveryServices = @serviceDiscovery.listHosts( host )

      # TODO
      # discoveryStatus auswerten!

      if( discoveryStatus == 201 )

        services = ( discoveryServices['hosts'] && discoveryServices['hosts']['services'] ) ? discoveryServices['hosts']['services'] : nil

        services.each do |s|
          s.last.reject! { |k| k == 'description' }
          s.last.reject! { |k| k == 'application' }
        end

        cm = Hash.new()
        cm = { 'cm' => services }

        icingaResult = @icinga.addHost( host, cm )
        icingaStatus = @icinga.status

        @log.debug( icingaResult )
        @log.debug( icingaStatus )

#        @grafana.addDashbards( host, force )

      end

      @status  = 200
      @message = 'host successfuly added'

    else

      return {
        :status  => 400,
        :message => 'need hostname to add to monitoring'
      }
    end

  end


  def removeHost( host, force = false )

    if( host.to_s != '' )

      icingaResult = @icinga.deleteHost( host )
      icingaStatus = @icinga.status

      return  icingaResult

      result = @serviceDiscovery.deleteHost( host )
      status = @serviceDiscovery.status

      if( status == 200 and force == true )

        @grafana.deleteDashboards( host )

      end
    else

      return {
        :status  => 400,
        :message => 'need hostname to remove from monitoring'
      }
    end

  end


  def listHost( host = nil )

    return @serviceDiscovery.listHosts( host )

  end

end

# ------------------------------------------------------------------------------------------

m = Monitoring.new()

puts m.listHost()
puts m.removeHost( 'monitoring-16-01' )
puts m.addHost( 'monitoring-16-01' )
# puts m.removeHost( 'blueprint-box' )


# EOF
