
require 'rest-client'
require 'json'
require 'logger'

module Grafana

  require_relative 'http_request'
  require_relative 'user'
  require_relative 'users'
  require_relative 'datasource'
  require_relative 'organization'
  require_relative 'organizations'
  require_relative 'dashboard'
  require_relative 'dashboard_template'
  require_relative 'snapshot'
  require_relative 'frontend'
  require_relative 'login'
  require_relative 'admin'
  require_relative 'version'

  class Client

    attr_reader :debug, :session_cookies, :headers, :logger, :api_instance

    include Grafana::HttpRequest
#     include Grafana::User
#     include Grafana::Users
#     include Grafana::Datasource
#     include Grafana::Organization
#     include Grafana::Organizations
    include Grafana::Dashboard
    include Grafana::DashboardTemplate
#     include Grafana::Snapshot
#     include Grafana::Frontend
    include Grafana::Login
#     include Grafana::Admin

    def initialize( host = 'localhost', port = 3000, user = 'admin', pass = '', settings = {} )


      file      = File.open( '/tmp/monitor-grafana.log', File::WRONLY | File::APPEND | File::CREAT )
      file.sync = true
      @log = Logger.new( file, 'weekly', 1024000 )
#      @log = Logger.new( STDOUT )
      @log.level = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S"
      @log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      if settings.has_key?('timeout') && settings['timeout'].to_i <= 0
        settings['timeout'] = 5
      end

      if settings.has_key?('open_timeout') && settings['open_timeout'].to_i <= 0
        settings['open_timeout'] = 5
      end

      if settings.has_key?('headers') && settings['headers'].class.to_s != 'Hash'
        settings['headers'] = {}
      end

      if settings.has_key?('url_path') && settings['url_path'].class.to_s != 'String'
        settings['url_path'] = ''
      end

      proto = ( settings.has_key?('ssl') && settings['ssl'] == true ? 'https' : 'http')

      url = sprintf( '%s://%s:%s%s', proto, host, port, settings['url_path'] )

      @log.debug("Initializing API client #{url}")
      @log.debug("Options: #{settings}")

      @api_instance = RestClient::Resource.new(
        "#{url}",
        :timeout      => settings['timeout'],
        :open_timeout => settings['open_timeout'],
        :headers      => settings['headers']
      )

      @debug = (settings['debug'] ? true : false)
#       @logger = Logger.new(STDOUT)
      @headers = nil

      self.login( user, pass )

      return self
    end

    def login( user = 'admin', pass = 'admin' )

      @log.debug("Attempting to establish user session")
      request_data = {
        'User'     => user,
        'Password' => pass
      }

      begin
        resp = @api_instance['/login'].post(
          request_data.to_json,
          { :content_type => 'application/json; charset=UTF-8' }
        )
        @session_cookies = resp.cookies
        if resp.code.to_i == 200
          @headers = {
            :content_type => 'application/json; charset=UTF-8',
            :cookies      => @session_cookies
          }
          return true
        else
          return false
        end
      rescue => e
        @log.error("Error running POST request on /login: #{e}")
        @log.error("Request data: #{request_data.to_json}")
        return false
      end
      @log.debug("User session initiated")
    end

  end # End of Client class

end # End of GrafanaApi module
