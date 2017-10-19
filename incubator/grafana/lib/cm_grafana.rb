
require 'grafana'

require_relative 'logging'
require_relative 'monkey'
#require_relative 'cache'
#require_relative 'job-queue'
#require_relative 'message-queue'
#require_relative 'storage'
#require_relative 'mbean'

require_relative 'grafana/configure_server'
# require_relative 'grafana/queue'

#require_relative 'grafana/coremedia/tools'
#require_relative 'grafana/coremedia/dashboard'

puts Grafana::VERSION

class CMGrafana < Grafana::Client

  include Logging

#   include CMGrafana::ConfigureServer

#   include Grafana::Client
#   include Grafana::Login

  def initialize( settings = {} )

    logger.debug( "CMGrafana.initialize( #{settings} )" )

    host                = settings.dig(:grafana, :host)          || 'localhost'
    port                = settings.dig(:grafana, :port)          || 80
    @user               = settings.dig(:grafana, :user)          || 'admin'
    @password           = settings.dig(:grafana, :password)      || ''
    url_path            = settings.dig(:grafana, :url_path)      || ''
    ssl                 = settings.dig(:grafana, :ssl)           || false
    @timeout            = settings.dig(:grafana, :timeout)       || 5
    @open_timeout       = settings.dig(:grafana, :open_timeout)  || 5
    @http_headers       = settings.dig(:grafana, :headers)       || {}

    super

    version       = '1.96.1'
    date          = '2017-10-16'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Grafana Client' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016-2017 Coremedia' )
    logger.info( '  used Services:' )
    logger.info( "    - grafana      : #{host}:#{port}#{url_path}" )
    logger.info( '-----------------------------------------------------------------' )

    @logged_in = login( { :user => @user, :password => @password } )

  end

#     def configure_server( params )
#
#       config_file = params.dig(:config_file)
#
#       if( !config_file.nil? && File.file?(config_file) )
#
#         begin
#
#           @config      = YAML.load_file( config_file )
#
#         rescue Exception
#
#           logger.error( 'wrong result (no yaml)')
#           logger.error( "#{$!}" )
#
#           raise( 'no valid yaml File' )
#           exit 1
#         end
#       else
#         logger.error( sprintf( 'Config File %s not found!', config_file ) )
#       end
#
#
#
#     end

end

