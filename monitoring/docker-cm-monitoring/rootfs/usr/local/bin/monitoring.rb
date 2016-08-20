#!/usr/bin/ruby
#
# 20.08.2016 - Bodo Schulz
#
#
# v0.0.1

# -----------------------------------------------------------------------------

require 'yaml'

require_relative 'discover'
require_relative 'grafana'
require_relative 'tools'

config_file = '/etc/cm-monitoring.yaml'

if( File.exist?( config_file ) )

  config = YAML.load_file( config_file )

  @logDir    = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']              : '/tmp/log'
  @cacheDir  = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']            : '/tmp/cache'

  @interval  = config['monitoring']['collectd-plugin']['interval'] ? config['monitoring']['collectd-plugin']['interval'] : 15

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
      'log_dir'      => @logDirectory,
      'cache_dir'    => @cacheDir,
      'jolokia_host' => @jolokia_host,
      'jolokia_port' => @jolokia_port
    }

    grafanaConfig = {
      'log_dir'      => @logDirectory,
      'cache_dir'    => @cacheDir,
      'grafana_host' => @grafana_host,
      'grafana_port' => @grafana_port,
      'grafana_path' => @grafana_path,
      'template_dir' => @template_dir
    }

    @discoveryService = Discover.new( serviceDiscoverConfig )
    @grafana          = Grafana.new( grafanaConfig )

  end


  def readConfigFile()

    configFile = '/etc/cm-monitoring.yaml'

    if( File.exist?( options[:config] ) )

      config = YAML.load_file( options[:config] )

      @logDirectory     = config['monitoring']['log_dir']                 ? config['monitoring']['log_dir']                  : '/tmp/log'
      @cacheDir         = config['monitoring']['cache_dir']               ? config['monitoring']['cache_dir']                : '/tmp/cache'

      @jolokia_host     = config['monitoring']['jolokia']['host']         ? config['monitoring']['jolokia']['host']          : 'localhost'
      @jolokia_port     = config['monitoring']['jolokia']['port']         ? config['monitoring']['jolokia']['port']          : 8080

      @grafana_host     = config['monitoring']['grafana']['host']         ? config['monitoring']['grafana']['host']          : 'localhost'
      @grafana_port     = config['monitoring']['grafana']['port']         ? config['monitoring']['grafana']['port']          : 3000
      @grafana_path     = config['monitoring']['grafana']['path']         ? config['monitoring']['grafana']['path']          : nil

      @template_dir     = config['monitoring']['grafana']['template_dir'] ? config['monitoring']['grafana']['template_dir']  : '/var/tmp/templates'

    else

      @log.info( 'no configuration exists, use default settings' )

      @logDirectory     = '/tmp/log'
      @cacheDir         = '/tmp/cache'

      @jolokia_host     = 'localhost'
      @jolokia_port     = 8080

      @grafana_host     = 'localhost'
      @grafana_port     = 3000
      @grafana_path     = nil
      @template_dir     = '/var/tmp/templates'

    end


  end


  def addHost( host, force = false )

    if( host.to_s != '' )

      result = @discoveryService.addHost( host, [], force )
      status = @discoveryService.status

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

      result = @discoveryService.deleteHost( host )
      status = @discoveryService.status

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


  def listHost( host = '' )

    return @discoveryService.listHosts( host )

  end

end

# EOF
