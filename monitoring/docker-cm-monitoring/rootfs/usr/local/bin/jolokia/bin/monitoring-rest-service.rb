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

require sprintf( '%s/discover', lib_dir )
require sprintf( '%s/grafana', lib_dir )

module Sinatra
  class Monitoring < Base

    configure do
      enable :logging

      logDirectory = "#{settings.root}/logs"

      Dir.mkdir( logDirectory ) unless File.exist?( logDirectory )

      file      = File.open( "#{logDirectory}/#{settings.environment}.log", File::WRONLY | File::APPEND | File::CREAT )
      file.sync = true

      use Rack::CommonLogger, file
    end

    set :app_file, caller_files.first || $0
    set :run, Proc.new { $0 == app_file }

    if( run? && ARGV.any? )
      require 'optparse'

      OptionParser.new { |op|
        op.on('-x')        {       set :lock, true }
        op.on('-e env')    { |val| set :environment, val.to_sym }
        op.on('-s server') { |val| set :server, val }
        op.on('-p port')   { |val| set :port, val.to_i }
        op.on('-o addr')   { |val| set :bind, val }
      }.parse!( ARGV.dup )
    end

    h = Discover.new()
    g = Grafana.new()

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

# #       puts h.status
# #       puts h.message
#       if( h.status == 201 )
#
# #         s = h.listHosts( host ).to_json
# #         puts s
#
#         services = h.services
#
#         puts services.keys
#
#         services.each do |s,v|
#           puts s
#           puts v['port']
#         end
#       end

#       response.status = h.status
#       status.to_json
    end

    # create new host
    post '/:host/:force' do

      host = params[:host]

      content_type :json
      status = h.addHost( params[:host], [], true )

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
