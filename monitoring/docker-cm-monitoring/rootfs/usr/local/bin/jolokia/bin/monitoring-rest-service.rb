#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v0.5.5

# -----------------------------------------------------------------------------

lib_dir    = File.expand_path( '../../lib', __FILE__ )

# -----------------------------------------------------------------------------

require 'sinatra/base'
require 'logger'
require 'json'
require 'yaml'
require 'fileutils'

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

    h = Discover.new( { 'log_dir' => @logDirectory, 'cache_dir' => @cacheDir, 'jolokia_host' => @jolokia_host, 'jolokia_port' => @jolokia_port } )
    g = Grafana.new( { 'log_dir' => @logDirectory, 'cache_dir' => @cacheDir, 'grafana_host' => @grafana_host, 'grafana_port' => @grafana_port, 'grafana_path' => @grafana_path, 'template_dir' => @template_dir } )

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

      host = params[:host]

      content_type :json
      status = h.deleteHost( host ).to_json
      g.deleteDashboards( host )

      response.status = h.status
      status.to_json

    end



    run! if app_file == $0

  end

end

# EOF
