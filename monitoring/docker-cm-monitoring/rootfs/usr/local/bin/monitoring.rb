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

@config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( @config_file ) )

  config = YAML.load_file( @config_file )

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

#     configFile = '/etc/cm-monitoring.yaml'
#
#     if( File.exist?( configFile ) )

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

#     else
#
#       @log.info( 'no configuration exists, use default settings' )
#
#       @logDirectory     = '/tmp/log'
#       @cacheDir         = '/tmp/cache'
#
#       @jolokia_host     = 'localhost'
#       @jolokia_port     = 8080
#
#       @grafana_host     = 'localhost'
#       @grafana_port     = 3000
#       @grafana_path     = nil
#       @template_dir     = '/var/tmp/templates'
#
#     end


  end


  def addHost( host, force = false )

    if( host.to_s != '' )

      icingaResult = @icinga.addHost( host )
      icingaStatus = @icinga.status

      return  icingaResult

      result = @serviceDiscovery.addHost( host, [], force )
      status = @serviceDiscovery.status

      if( status == 200 )

        @grafana.addDashbards( host, force )


      end


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
puts m.addHost( 'blueprint-box' )
puts m.removeHost( 'blueprint-box' )


# EOF
