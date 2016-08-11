#!/usr/bin/ruby
#
# 31.07.2016 - Bodo Schulz
#
#
# v0.5.4

# -----------------------------------------------------------------------------

lib_dir    = File.expand_path( '../../lib', __FILE__ )

# -----------------------------------------------------------------------------

require 'sinatra/base'
require 'logger'
require 'json'
require 'yaml'

require sprintf( '%s/discover', lib_dir )
require sprintf( '%s/grafana', lib_dir )

module Sinatra
  class Monitoring < Base

    options = {
      :log_dir   => '/var/log/monitoring',
      :cache_dir => '/var/cache/monitoring',
      :config    => '/etc/cm-monitoring.yaml'
    }

    configure do
      enable :logging
      disable :dump_errors

      set :environment, :production

      if( File.exist?( options[:config] ) )

        config = YAML.load_file( options[:config] )
#         puts config.inspect

        @logDir           = config['monitoring']['log_dir']              ? config['monitoring']['log_dir']              : '/tmp/log'
        @cacheDir         = config['monitoring']['cache_dir']            ? config['monitoring']['cache_dir']            : '/tmp/cache'

        @restService_port = config['monitoring']['rest-service']['port'] ? config['monitoring']['rest-service']['port'] : 4567
        @restService_bind = config['monitoring']['rest-service']['bind'] ? config['monitoring']['rest-service']['bind'] : '0.0.0.0'

        @jolokia_host     = config['monitoring']['jolokia']['host']      ? config['monitoring']['jolokia']['host']      : 'localhost'
        @jolokia_port     = config['monitoring']['jolokia']['port']      ? config['monitoring']['jolokia']['port']      : 8080

        @grafana_host     = config['monitoring']['grafana']['host']      ? config['monitoring']['grafana']['host']      : 'localhost'
        @grafana_port     = config['monitoring']['grafana']['port']      ? config['monitoring']['grafana']['port']      : 3000
        @grafana_path     = config['monitoring']['grafana']['path']      ? config['monitoring']['grafana']['path']      : nil

      else
        puts "no configuration exists, use default settings"

        @jolokia_host = 'localhost'
        @jolokia_port = 8080

      end

      if( ! File.exist?( @logDir ) )
        Dir.mkdir( @logDir )
      end

      if( ! File.exist?( @cacheDir ) )
        Dir.mkdir( @cacheDir )
      end

      file      = File.open( sprintf( '%s/rest-service.log', @logDir ), File::WRONLY | File::APPEND | File::CREAT )
      file.sync = true

      use Rack::CommonLogger, file

    end

    set :app_file, caller_files.first || $0
    set :run, Proc.new { $0 == app_file }
    set :dump_errors, false

    set :bind, @restService_bind
    set :port, @restService_port.to_i
#
#    if( run? && ARGV.any? )
#      require 'optparse'
#
#      OptionParser.new { |op|
#        op.on('-x')        {       set :lock, true }
#        op.on('-e env')    { |val| set :environment, val.to_sym }
#        op.on('-s server') { |val| set :server, val }
#        op.on('-p port')   { |val| set :port, val.to_i }
#        op.on('-o addr')   { |val| set :bind, val }
#      }.parse!( ARGV.dup )
#    end

    h = Discover.new( { 'log_dir' => @logDir, 'cache_dir' => @cacheDir, 'jolokia_host' => @jolokia_host, 'jolokia_port' => @jolokia_port } )
    g = Grafana.new( { 'log_dir' => @logDir, 'cache_dir' => @cacheDir, 'grafana_host' => @grafana_host, 'grafana_port' => @grafana_port, 'grafana_path' => @grafana_path } )

    error do
      'Sorry there was a nasty error - ' + env['sinatra.error'].message
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

    # create new host
    post '/:host' do

      host = params[:host]

      content_type :json
      status = h.addHost( host )
      g.addDashbards( host )

      response.status = h.status
      status.to_json
    end

    # create new host
    post '/:host/:force' do

      host = params[:host]

      content_type :json
      status = h.addHost( host, [], true )
      g.addDashbards( host, true)

      response.status = h.status
      status.to_json

    end

    # delete a host
    delete '/:host' do
      content_type :json
      h.deleteHost( params[:host] ).to_json
      g.deleteDashboards(params[:host])
    end

    # create new host
    post '/config/jolokia' do

      jolokia_host = params['host']
      jolokia_port = params['port']

      content_type :json
#      status = h.addHost( host )



    end

    run! if app_file == $0

  end

end

# EOF
