#!/usr/bin/ruby
#
# 09.01.2017 - Bodo Schulz
#
#
# v0.0.0

# -----------------------------------------------------------------------------

require 'json'
require 'timeout'
require 'fileutils'
require 'time'
require 'date'
require 'time_difference'
require 'rest-client'

require_relative 'logging'
# require_relative '../../lib/message-queue'
# require_relative '../../lib/storage'
require_relative 'grafana/http_request'
require_relative 'grafana/user'
require_relative 'grafana/users'
require_relative 'grafana/datasource'
require_relative 'grafana/organization'
require_relative 'grafana/organizations'
require_relative 'grafana/dashboard'
require_relative 'grafana/dashboard_template'
require_relative 'grafana/snapshot'
require_relative 'grafana/login'
require_relative 'grafana/admin'
require_relative 'grafana/version'

# -----------------------------------------------------------------------------

module Grafana

  class Client

    include Logging

    include Grafana::HttpRequest
    include Grafana::User
    include Grafana::Users
    include Grafana::Datasource
    include Grafana::Organization
    include Grafana::Organizations
    include Grafana::Dashboard
    include Grafana::DashboardTemplate
    include Grafana::Snapshot
#     include Grafana::Frontend
    include Grafana::Login
    include Grafana::Admin

    def initialize( params = {} )

      logger.debug( params )

      host     = params[:host]     ? params[:host]     : 'localhost'
      port     = params[:port]     ? params[:port]     : 80
      user     = params[:user]     ? params[:user]     : 'admin'
      password = params[:password] ? params[:password] : ''
      settings = params.keys.include?(:settings) ? params[:settings] : {}

      @debug   = ( settings[:debug] ? true : false )
      @apiInstance = nil

      if( settings.has_key?(:timeout) && settings[:timeout].to_i <= 0 )
        settings[:timeout] = 5
      end

      if( settings.has_key?(:open_timeout) && settings[:open_timeout].to_i <= 0 )
        settings[:open_timeout] = 5
      end

      if( settings.has_key?(:headers) && settings[:headers].class.to_s != 'Hash' )
        settings['headers'] = {}
      end

      if( settings.has_key?(:url_path) && settings[:url_path].class.to_s != 'String' )
        settings[:url_path] = ''
      end

      proto = ( settings.has_key?(:ssl) && settings[:ssl] == true ? 'https' : 'http')
      @url  = sprintf( '%s://%s:%s%s', proto, host, port, settings[:url_path] )

      logger.debug( "Initializing API client #{@url}" )
      logger.debug( "Options: #{settings}" )

      begin

        @apiInstance = RestClient::Resource.new(
          @url,
          :timeout      => settings[:timeout],
          :open_timeout => settings[:open_timeout],
          :headers      => settings[:headers],
          :verify_ssl   => false
        )
      rescue => e
        logger.error( e )
      end

      @headers = nil

      if( false ) #settings['headers'].has_key?('Authorization') )
        # API key Auth
        @headers = {
          :content_type  => 'application/json; charset=UTF-8',
          :Authorization => settings['headers']['Authorization']
        }
      else
        # Regular login Auth
        self.login( { :user => user, :password => password } )

        logger.debug( @headers )
      end

      return self
    end


    def login( params = {} )

      user     = params[:user]     ? params[:user]     : 'admin'
      password = params[:password] ? params[:password] : 'admin'

      logger.debug( "Attempting to establish user session" )

      request_data = { 'User' => user, 'Password' => password }

      begin
        resp = @apiInstance['/login'].post(
          request_data.to_json,
          { :content_type => 'application/json; charset=UTF-8' }
        )
        @sessionCookies = resp.cookies
        if( resp.code.to_i == 200 )
          @headers = {
            :content_type => 'application/json; charset=UTF-8',
            :cookies      => @sessionCookies
          }
          return true
        else
          return false
        end
      rescue => e
        logger.debug( "Error running POST request on /login: #{e}" )
        logger.debug( "Request data: #{request_data.to_json}" )
        return false
      end
      logger.debug("User session initiated")
    end

  end # End of Client class

end

# EOF

