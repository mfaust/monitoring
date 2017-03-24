#!/usr/bin/ruby
#
# 05.10.2016 - Bodo Schulz
#
#
# v2.1.0

# -----------------------------------------------------------------------------

require 'sinatra/base'
require 'logger'
require 'json'
require 'yaml'
require 'fileutils'
require 'resolve/hostname'

require_relative 'monitoring'
require_relative '../lib/logging'

module Sinatra

  class MonitoringRest < Base

    include Logging

    configure do

      set :environment, :production

      # default configuration
      @logDirectory     = '/tmp/log'
      @cacheDir         = '/tmp/cache'

      @restServicePort  = 4567
      @restServiceBind  = '0.0.0.0'

      if( File.exist?( '/etc/cm-monitoring.yaml' ) )

        config = YAML.load_file( '/etc/cm-monitoring.yaml' )

        @logDirectory     = config['logDirectory']         ? config['logDirectory']         : '/tmp/log'
        @cacheDir         = config['cacheDirectory']       ? config['cacheDirectory']       : '/tmp/cache'
        @restServicePort  = config['rest-service']['port'] ? config['rest-service']['port'] : 4567
        @restServiceBind  = config['rest-service']['bind'] ? config['rest-service']['bind'] : '0.0.0.0'

      else
        puts "no configuration exists, use default settings"
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

    before do
      content_type :json
    end

    before '/v2/*/:host' do
      request.body.rewind
      @request_paylod = request.body.read
    end

    # -----------------------------------------------------------------------------
    # HELP

    # prints out a little help about our ReST-API
    get '/v2/help' do

      send_file File.join( settings.public_folder, 'help' )

    end

    # currently not supported
    get '/' do

      send_file File.join( settings.public_folder, 'help' )

    end

    # -----------------------------------------------------------------------------
    # CONFIGURE

    #
    # curl -X POST http://localhost/api/v2/config/foo \
    #  --data '{ "ports": [200,300] }'
    #
    post '/v2/config/:host' do

      host            = params[:host]

      payload         =  @request_paylod
      @request_paylod = nil

      result = m.writeHostConfiguration( host, paylod )

      status result[:status]

      result

    end

    #
    # curl http://localhost/api/v2/config/foo
    #
    get '/v2/config/:host' do

      host   = params[:host]
      result = m.getHostConfiguration( host )

      status result[:status]

      result

    end

    #
    # curl -X DELETE http://localhost/api/v2/config/foo
    #
    delete '/v2/config/:host' do

      host   = params[:host]
      result = m.removeHostConfiguration( host )

      status result[:status]

      result

    end

    # -----------------------------------------------------------------------------
    # HOST

    #
    # curl -X POST http://localhost/api/v2/host/foo \
    #  --data '{ "force": false, "grafana": true, "icinga": false }'
    #
    post '/v2/host/:host' do

      host            = params[:host]
      payload         = @request_paylod
      @request_paylod = nil

      logger.debug( sprintf( 'POST \'/v2/host/:host\' - \'%s\', \'%s\'', host, payload ) )

      result = m.addHost( host, payload )

      status result[:status]

      result

    end

    # get information about all hosts
    get '/v2/host' do

      result = m.listHost( nil, request.env )

#       status = result[:status]

      result

    end

    # get information about given 'host'
    get '/v2/host/:host' do

      host   = params[:host]
      result = m.listHost( host, request.env )

#       status = result[:status]

      result

    end

    # remove named host from monitoring
    delete '/v2/host/:host' do

      host   = params[:host]
      result = m.removeHost( host, @request_paylod )

      logger.debug( result )

#       status result[:status]

      result

    end

    # -----------------------------------------------------------------------------
    # ANNOTATIONS

    post '/v2/annotation/:host' do

      host   = params[:host]
      result = m.addAnnotation( host, @request_paylod )

#       status = result[:status]

      result

    end

    # -----------------------------------------------------------------------------



    # -----------------------------------------------------------------------------
    run! if app_file == $0
    # -----------------------------------------------------------------------------
  end
end

# EOF
