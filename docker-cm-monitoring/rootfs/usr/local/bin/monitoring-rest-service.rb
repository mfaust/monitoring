#!/usr/bin/ruby
#
# 27.08.2016 - Bodo Schulz
#
#
# v1.0.0

# -----------------------------------------------------------------------------

lib_dir    = File.expand_path( '../../lib', __FILE__ )

# -----------------------------------------------------------------------------

require 'sinatra/base'
require 'logger'
require 'json'
require 'yaml'
require 'fileutils'
require 'resolve/hostname'

#require_relative 'discover'
#require_relative 'tools'
require sprintf( '%s/discover', lib_dir )
require sprintf( '%s/grafana' , lib_dir )
require sprintf( '%s/graphite', lib_dir )

module Sinatra
  class MonitoringRest < Base

    options = {
      :log_dir   => '/var/log/monitoring',
      :cache_dir => '/var/cache/monitoring',
      :config    => '/etc/cm-monitoring.yaml'
    }

    configure do
      enable :logging
#       disable :dump_errors

      set :environment, :production

      if( File.exist?( options[:config] ) )

        config = YAML.load_file( options[:config] )

        @logDirectory     = config['monitoring']['log_dir']                 ? config['monitoring']['log_dir']                  : '/tmp/log'
        @cacheDir         = config['monitoring']['cache_dir']               ? config['monitoring']['cache_dir']                : '/tmp/cache'

        @restService_port = config['monitoring']['rest-service']['port']    ? config['monitoring']['rest-service']['port']     : 4567
        @restService_bind = config['monitoring']['rest-service']['bind']    ? config['monitoring']['rest-service']['bind']     : '0.0.0.0'

        @jolokia_host     = config['monitoring']['jolokia']['host']         ? config['monitoring']['jolokia']['host']          : 'localhost'
        @jolokia_port     = config['monitoring']['jolokia']['port']         ? config['monitoring']['jolokia']['port']          : 8080

        @grafana_host     = config['monitoring']['grafana']['host']         ? config['monitoring']['grafana']['host']          : 'localhost'
        @grafana_port     = config['monitoring']['grafana']['port']         ? config['monitoring']['grafana']['port']          : 3000
        @grafana_path     = config['monitoring']['grafana']['path']         ? config['monitoring']['grafana']['path']          : nil

        graphite = config['monitoring']['graphite'] ? config['monitoring']['graphite'] : nil

        if( graphite != nil )
          @graphiteHost        = graphite['host']         ? graphite['host']         : 'localhost'
          @graphitePort        = graphite['port']         ? graphite['port']         : 2003
          @graphiteHttpPort    = graphite['http-port']    ? graphite['http-port']    : 8080
          @graphiteFixTimezone = graphite['fix-timezone'] ? graphite['fix-timezone'] : true
        end

        @template_dir     = config['monitoring']['grafana']['template_dir'] ? config['monitoring']['grafana']['template_dir']  : '/var/tmp/templates'

      else
        puts "no configuration exists, use default settings"

        @logDirectory     = '/tmp/log'
        @cacheDir         = '/tmp/cache'

        @restService_port = 4567
        @restService_bind = '0.0.0.0'

        @jolokia_host     = 'localhost'
        @jolokia_port     = 8080

        @grafana_host     = 'localhost'
        @grafana_port     = 3000
        @grafana_path     = nil
        @template_dir     = '/var/tmp/templates'

      end

      if( ! File.exist?( @logDirectory ) )
        Dir.mkdir( @logDirectory )
      end

      if( ! File.exist?( @cacheDir ) )
        Dir.mkdir( @cacheDir )
      end

      FileUtils.chmod( 1775, @logDirectory )
      FileUtils.chmod( 0775, @cacheDir )
      FileUtils.chown( 'nobody', 'nobody', @logDirectory )

      file      = File.open( sprintf( '%s/rest-service.log', @logDirectory ), File::WRONLY | File::APPEND | File::CREAT )
      file.sync = true

      use Rack::CommonLogger, file

    end

    set :app_file, caller_files.first || $0
    set :run, Proc.new { $0 == app_file }
    set :dump_errors, true
    set :show_exceptions, true

    set :bind, @restService_bind
    set :port, @restService_port.to_i


    serviceDiscoveryOptions = {
      'log_dir'               => @logDirectory,
      'cache_dir'             => @cacheDir,
      'jolokia_host'          => @jolokia_host,
      'jolokia_port'          => @jolokia_port,
      'scanDiscovery'         => @scanDiscovery,
      'serviceConfigFile'     => '/etc/cm-service.json'
    }

    grafanaOptions = {
      'log_dir'               => @logDirectory,
      'cache_dir'             => @cacheDir,
      'grafana_host'          => @grafana_host,
      'grafana_port'          => @grafana_port,
      'grafana_path'          => @grafana_path,
      'template_dir'          => @template_dir
    }

    graphiteOptions = {
      'logDirectory'          => @logDirectory,
      'graphiteHost'          => @graphiteHost,
      'graphiteHttpPort'      => @graphiteHttpPort,
      'graphitePort'          => @graphitePort
    }

    h = ServiceDiscovery.new( serviceDiscoveryOptions )
    g = Grafana.new( grafanaOptions )
    graphite = GraphiteAnnotions::Client.new( graphiteOptions )

    error do
      msg = "ERROR\n\nThe monitoring-rest-service has nasty error - " + env['sinatra.error']

      msg.message
    end

    get '/' do
      content_type :json
      h.listHosts().to_json
    end

    # get information about given 'host'
    get '/:host' do
      content_type :json
      h.listHosts( params[:host] ).to_json
    end

    # create new host - without grafana dashboards
    post '/h/:host' do

      host = params[:host]

      content_type :json
      status          = h.addHost( host )
      response.status = h.status
      status.to_json
    end

    # create new host - without grafana dashboards
    post '/h/:host/:services' do

      host     = params[:host]
      services = params[:services]

#      content_type :json
#      status          = h.addHost( host )
#      response.status = h.status
#      status.to_json
    end

    # create new host
    post '/g/:hosts' do

      hostsParam = params[:hosts]
      hosts = hostsParam.split('+')

      content_type :json

      result = g.addGroupOverview( hosts )

      response.status = result[:status]
      result.to_json

    end

    # create new host
    post '/g/:hosts/force' do

      hostsParam = params[:hosts]
      hosts = hostsParam.split('+')

      content_type :json

      result = g.addGroupOverview( hosts, true )

      response.status = result[:status]
      result.to_json

    end

    # create new host - with grafana dashboards
    post '/:host' do

      host = params[:host]
      content_type :json
      status          = h.addHost( host )
      g.addDashbards( host )

      response.status = h.status
      status.to_json
    end

    # create new host
    post '/:host/:force' do

      host = params[:host]

      content_type :json
      status = h.addHost( host, [], true )
      g.addDashbards( host, true )

      response.status = h.status
      status.to_json

    end

    # delete a host
    delete '/:host' do

      host = params[:host]

      content_type :json
      status = h.deleteHost( host )

      response.status = h.status
      status.to_json

    end

    # delete a host and there dashboards
    delete '/:host/:force' do

      host = params[:host]

      content_type :json
      status = h.deleteHost( host )
      g.deleteDashboards( host )

      response.status = h.status
      status.to_json

    end

    # dashboards
    # recreate all dashboards for the given host
    post '/d/:host/:force' do

      host = params[:host]

      content_type :json

      g.addDashbards( host, true )

    end


    # annotations ....
    #  Host [create|destroy]
    post '/a/node/:type/:host' do

      host = params[:host]
      type = params[:type]

      case type
      when 'create'
        graphite.nodeCreatedAnnotation( host )
      when 'destroy'
        graphite.nodeDestroyedAnnotation( host )
      else
        puts "The Type #{type} for Node Annotation are NOT supported! Please use 'create' or 'destroy'"

      end

    end

    # Loadtests [start|stop]
    post '/a/loadtest/:type/:host' do

      host = params[:host]
      type = params[:type]

      case type
      when 'start'
        graphite.loadTestStartAnnotation( host )
      when 'stop'
        graphite.loadTestStopAnnotation( host )
      else
        puts "The Type #{type} for Loadtest Annotation are NOT supported! Please use 'start' or 'stop'"
      end

    end

    #
    post '/a/start/:host/:annotation' do

    end

    #
    post '/a/stop/:host/:annotation' do

    end


    run! if app_file == $0

  end

end

# EOF
