#


require 'sinatra/base'
require 'logger'
require 'json'

require './lib/host'

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

    error do
      'Sorry there was a nasty error - ' + env['sinatra.error'].message
    end

    get '/' do
      "here comes the monitoring ReST Interface ...\n"
    end

    # get information about given 'host'
    get '/:host' do
#      raise ' fooo'
#      params[:host]
      "Information about - '#{params[:host]}'"
    end

    # create new host
    post '/:host' do
      "Create Host '#{params[:host]}'"

      ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099]
      h = Discover.new()
      h.run( params[:host] , ports )
    end

    # delete a host
    delete '/:host' do
      "Delete Host '#{params[:host]}'"

    end

    # push - change a host
    push '/:host' do
      "Change Host '#{params[:host]}'"

    end


    run! if app_file == $0

  end

end


