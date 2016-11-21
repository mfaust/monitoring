#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.0.1

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

      set :environment, :production

      if( File.exist?( '/etc/cm-monitoring.yaml' ) )

        config = YAML.load_file( '/etc/cm-monitoring.yaml' )

        @logDirectory     = config['logDirectory']         ? config['logDirectory']         : '/tmp/log'
        @cacheDir         = config['cacheDirectory']       ? config['cacheDirectory']       : '/tmp/cache'

        @restServicePort  = config['rest-service']['port'] ? config['rest-service']['port'] : 4567
        @restServiceBind  = config['rest-service']['bind'] ? config['rest-service']['bind'] : '0.0.0.0'

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

    set :logging, true
    set :app_file, caller_files.first || $0
    set :run, Proc.new { $0 == app_file }
    set :dump_errors, true
    set :show_exceptions, true
    set :public_folder, '/var/www/monitoring'

    set :bind, @restServiceBind
    set :port, @restServicePort.to_i

    # -----------------------------------------------------------------------------

    options = {
     :logDirectory        => @logDirectory,
     :monitoringServices  => @monitoringServices
    }

    m = Monitoring.new( options )

    # -----------------------------------------------------------------------------

    error do
      msg = "ERROR\n\nThe monitoring-rest-service has nasty error - " + env['sinatra.error']

      msg.message
    end

    # -----------------------------------------------------------------------------

    before '/v2/*/:host' do
      request.body.rewind
      @request_paylod = request.body.read
    end

    # -----------------------------------------------------------------------------
    # GET

    # prints out a little help about our ReST-API
    get '/help' do

      send_file File.join( settings.public_folder, 'help' )

    end

    # currently not supported
    get '/' do
      content_type :json

      result = m.listHost( nil )

      response.status = result[:status]
      result.to_json
    end

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
    post '/:host/force' do
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
    post '/h/:host/force' do

      result = m.addHost( params[:host], true )

      response.status = result[:status]
      result.to_json
    end

    #
    # curl -X POST http://localhost/api/v2/config/foo -d '{ "ports": [200,300] }'
    #
    post '/v2/config/:host' do

      host   = params[:host]
      result = m.configureHost( host, @request_paylod )

      response.status = result[:status]
      result.to_json

    end

    #
    # curl -X POST http://localhost/api/v2/host/foo -d '{ "ports": [200,300] }'
    #
    post '/v2/host/:host' do

      host   = params[:host]
      puts @request_paylod.inspect

#      {
#        "discovery": false,
#        "icinga2": false,
#        "grafana": false,
#        "services": [
#          "cae-live-1",
#          "content-managment-server": { "port": 41000 }
#        ],
#        "tags": [
#          "development",
#          "git-0000000"
#        ]
#      }

    end



#     # create new host
#     #  including icinga2 and grafana
#     post '/h/:host/:tags' do
#       content_type :json
#
#       tags   = params[:tags]
#       result = m.addHost( params[:host], tags )
#
#       response.status = result[:status]
#       result.to_json
#     end

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
