#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.0.0

# -----------------------------------------------------------------------------

require 'sinatra/base'
require 'logger'
require 'json'
require 'yaml'
require 'fileutils'
require 'resolve/hostname'

require_relative 'monitoring'

module Sinatra
  class MonitoringRest < Base

    configure do
      enable :logging
#       disable :dump_errors

      set :environment, :production

      if( File.exist?( '/etc/cm-monitoring.yaml' ) )

        config = YAML.load_file( '/etc/cm-monitoring.yaml' )

        @logDirectory     = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']              : '/tmp/log'
        @cacheDir         = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']            : '/tmp/cache'

        @restServicePort  = config['monitoring']['rest-service']['port'] ? config['monitoring']['rest-service']['port'] : 4567
        @restServiceBind  = config['monitoring']['rest-service']['bind'] ? config['monitoring']['rest-service']['bind'] : '0.0.0.0'

      else
        puts "no configuration exists, use default settings"

        @logDirectory     = '/tmp/log'
        @cacheDir         = '/tmp/cache'

        @restServicePort  = 4567
        @restServiceBind  = '0.0.0.0'
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

    set :bind, @restServiceBind
    set :port, @restServicePort.to_i

    # -----------------------------------------------------------------------------

    options = {
     :logDirectory               => @logDirectory
    }

    m = Monitoring.new( options )

    # -----------------------------------------------------------------------------

    error do
      msg = "ERROR\n\nThe monitoring-rest-service has nasty error - " + env['sinatra.error']

      msg.message
    end

    # -----------------------------------------------------------------------------
    # GET
    # currently not supported
#    get '/' do
#      content_type :json
#      h.listHosts().to_json
#    end

    # get information about given 'host'
    get '/:host' do
      content_type :json

      result = m.listHost( params[:host] )

      response.status = result[:status]
      result.to_json

    end

    # -----------------------------------------------------------------------------
    # POST

    # DO NOT USE ANYMORE - THIS STYLE IS DEPRECATED
    # PLEASE USE "post '/h/:host'"
    # create new host
    #  including icinga2 and grafana
    post '/:host' do
      content_type :json

      result = m.addHost( params[:host] )

      response.status = result[:status]
      result.to_json
    end

    # DO NOT USE ANYMORE - THIS STYLE IS DEPRECATED
    # PLEASE USE "post '/h/:host/:force'"
    # create new host
    #  including icinga2 and grafana
    post '/:host/:force' do
      content_type :json

      result = m.addHost( params[:host], true )

      response.status = result[:status]
      result.to_json
    end

    # create new host
    #  including icinga2 and grafana
    post '/h/:host' do
      content_type :json

      result = m.addHost( params[:host] )

      response.status = result[:status]
      result.to_json
    end

    # delete EVERY dashboards and checks before create the host
    #  including icinga2 and grafana
    post '/h/:host/:force' do
      content_type :json

      result = m.addHost( params[:host], true )

      response.status = result[:status]
      result.to_json
    end

    # create new group of hosts
    post '/g/:hosts' do
      content_type :json

      hostsParam = params[:hosts]
      hosts      = hostsParam.split('+')

      result     = m.addGrafanaGroupOverview( hosts )

      response.status = result[:status]
      result.to_json
    end

    # delete EVERY dashboards before create the hostgroup
    post '/g/:hosts/force' do
      content_type :json

      hostsParam = params[:hosts]
      hosts      = hostsParam.split('+')

      result     = m.addGrafanaGroupOverview( hosts, true )

      response.status = result[:status]
      result.to_json
    end

    # annotations ....
    #  Host [create|destroy]
    post '/a/node/:type/:host' do

      host = params[:host]
      type = params[:type]

      case type
      when 'create'
        m.addAnnotation( host, 'create' )
      when 'destroy'
        m.addAnnotation( host, 'destroy' )
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
        m.addAnnotation( host, 'start' )
      when 'stop'
        m.addAnnotation( host, 'stop' )
      else
        puts "The Type #{type} for Loadtest Annotation are NOT supported! Please use 'start' or 'stop'"
      end
    end

    #
    post '/a/deployment/:host/:annotation' do

      host       = params[:host]
      annotation = params[:annotation]

      m.addAnnotation( host, 'deployment', annotation )
    end

    #
    post '/a/:host/:descr/:annotation/:tags' do

      host        = params[:hosts]
      annotation  = params[:annotation]
      description = params[:descr]
      tags        = params[:tags].split('+')

      m.addAnnotation( host, 'general', description, annotation, tags )
    end

    # -----------------------------------------------------------------------------
    # DELETE

    # delete a host
    # WITHOUT Grafana Dashboards
    delete '/:host' do
      content_type :json

      result = m.removeHost( params[:host] )

      response.status = result[:status]
      result.to_json
    end

    # delete a host
    delete '/:host/:force' do
      content_type :json

      result = m.removeHost( params[:host], true )

      response.status = result[:status]
      result.to_json
    end

    # -----------------------------------------------------------------------------



    # -----------------------------------------------------------------------------
    run! if app_file == $0
    # -----------------------------------------------------------------------------
  end
end

# EOF
