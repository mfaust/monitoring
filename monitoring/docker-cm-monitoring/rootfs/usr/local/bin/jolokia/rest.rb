#


require 'sinatra/base'
require 'logger'
require 'json'

require './lib/discover'

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
      content_type :json
      h.addHost( params[:host] ).to_json
    end

    # create new host
    post '/:host/:force' do
      content_type :json
      h.addHost( params[:host], [], true ).to_json
    end

    # delete a host
    delete '/:host' do
      content_type :json
      h.deleteHost( params[:host] ).to_json
    end



    run! if app_file == $0

  end

end


