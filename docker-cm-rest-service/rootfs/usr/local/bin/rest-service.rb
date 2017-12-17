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
require 'resolve/hostname'

require_relative '../lib/monitoring'

module Sinatra

  class MonitoringRest < Base

    include Logging

    configure do

      set :environment, :production

      @log_directory     = '/var/log'

      @rest_service_port = ENV.fetch('REST_SERVICE_PORT'      , 8080 )
      @rest_service_bind = ENV.fetch('REST_SERVICE_BIND'      , '0.0.0.0' )
      @mq_host           = ENV.fetch('MQ_HOST'                , 'beanstalkd' )
      @mq_port           = ENV.fetch('MQ_PORT'                , 11300 )
      @mq_queue          = ENV.fetch('MQ_QUEUE'               , 'mq-rest-service' )
      @redis_host        = ENV.fetch('REDIS_HOST'             , 'redis' )
      @redis_port        = ENV.fetch('REDIS_PORT'             , 6379 )

      @mysql_host        = ENV.fetch('MYSQL_HOST'             , 'database')
      @mysql_schema      = ENV.fetch('DISCOVERY_DATABASE_NAME', 'discovery')
      @mysql_user        = ENV.fetch('DISCOVERY_DATABASE_USER', 'discovery')
      @mysql_password    = ENV.fetch('DISCOVERY_DATABASE_PASS', 'discovery')


      #FileUtils.chmod( 1775, @log_directory )
      #FileUtils.chown( 'nobody', 'nobody', @log_directory )
      #
      #file      = File.new( sprintf( '%s/rest-service.log', @log_directory ), File::WRONLY | File::APPEND | File::CREAT )
      #file.sync = true
      #
      #use Rack::CommonLogger, file

    end

    set :logging, false
    set :app_file, caller_files.first || $0
    set :run, Proc.new { $0 == app_file }
    set :dump_errors, true
    set :show_exceptions, true
    set :public_folder, '/var/www/monitoring'

    set :bind, @rest_service_bind
    set :port, @rest_service_port.to_i

    # -----------------------------------------------------------------------------

    config = {
      :mq       => {
        :host      => @mq_host,
        :port      => @mq_port,
        :queue     => @mq_queue
      },
      :redis    => {
        :host      => @redis_host,
        :port      => @redis_port
      },
      :mysql    => {
        :host      => @mysql_host,
        :schema    => @mysql_schema,
        :user      => @mysql_user,
        :password  => @mysql_password
      }
    }

    m = Monitoring::Client.new( config )

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

    get '/health' do
      status 200
    end


    # -----------------------------------------------------------------------------
    # HELP

    # prints out a little help about our ReST-API
    get '/v2/help' do

      send_file File.join( settings.public_folder, 'help' )
    end

    # currently not supported
    get '/' do
      redirect '/v2/help'
      # send_file File.join( settings.public_folder, 'help' )
    end

    # -----------------------------------------------------------------------------
    # CONFIGURE

    #
    # curl -X POST http://localhost/api/v2/config/foo \
    #  --data '{ "ports": [200,300] }'
    #
#     post '/v2/config/:host' do
#
#       host            = params[:host]
#
#       payload         =  @request_paylod
#       @request_paylod = nil
#
#       result = m.writeHostConfiguration( host, paylod )
#
#       status result[:status]
#
#       result
#
#     end
#
#     #
#     # curl http://localhost/api/v2/config/foo
#     #
#     get '/v2/config/:host' do
#
#       host   = params[:host]
#       result = m.getHostConfiguration( host )
#
#       status result[:status]
#
#       result
#
#     end
#
#     #
#     # curl -X DELETE http://localhost/api/v2/config/foo
#     #
#     delete '/v2/config/:host' do
#
#       host   = params[:host]
#       result = m.removeHostConfiguration( host )
#
#       status result[:status]
#
#       result
#
#     end

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

      #logger.debug( sprintf( 'POST \'/v2/host/:host\' - \'%s\', \'%s\'', host, payload ) )

      result = m.add_host( host, payload )

      r = JSON.parse( result ) if( result.is_a?( String ) )

      result_status = r.dig('status').to_i

      status result_status

      JSON.pretty_generate(r) + "\n"
    end

    # get information about all hosts
    get '/v2/host' do

      result = m.list_host( nil, request.env )

      r = JSON.parse( result ) if( result.is_a?( String ) )

      result_status = r.dig('status').to_i

      status result_status

      JSON.pretty_generate(r) + "\n"
    end

    # get information about given 'host'
    get '/v2/host/:host' do

      host   = params[:host]
      result = m.list_host( host, request.env )

      r = JSON.parse( result ) if( result.is_a?( String ) )

      result_status = r.dig('status').to_i

      status result_status

      JSON.pretty_generate(r) + "\n"
    end

    # remove named host from monitoring
    delete '/v2/host/:host' do

      host   = params[:host]
      result = m.delete_host( host, @request_paylod )

      r = JSON.parse( result ) if( result.is_a?( String ) )

      result_status = r.dig('status').to_i

      status result_status

      JSON.pretty_generate(r) + "\n"
#       r = JSON.parse( result )
#
#       logger.debug( r )
#
#       status = r['status']
#       body   = r['message']
#
#       halt status, {'Content-Type' => 'text/json'}, result

    end

    # -----------------------------------------------------------------------------
    # ANNOTATIONS

    post '/v2/annotation/:host' do

      host   = params[:host]
      result = m.annotation( host: host, payload: @request_paylod )

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
