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
require_relative '../lib/storage'
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
require_relative 'grafana/coremedia/dashboard'

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
    include Grafana::Login
    include Grafana::Admin
    include Grafana::Coremedia::Dashboard
    include Grafana::Coremedia::Templates
    include Grafana::Coremedia::Annotations
    include Grafana::Coremedia::Tags

    # Returns a new instance of Client
    #
    # @param [Hash, #read] params the configure the Client
    # @option params [String] :host the Grafana Hostname (default: 'localhost')
    # @option params [String] :port the Grafana Port (default: 80)
    # @option params [String] :user the Grafana User for Login (default: 'admin')
    # @option params [String] :password the Grafana Users Password for Login (default: '')
    # @option params [Bool] :debug enabled debug Output
    # @option params [Integer] :timeout Timeout for the RestClient
    # @option params [Integer] :open_timeout
    # @option params [String] :url_path advanced URL Path, when Grafana is located behind a Proxy Services, or the uri_path has changed
    # @option params [Bool] :ssl enable SSL Connections
    # @option params [Hash] :headers optional Header for an API Key Login
    # @example to create an new Instance
    #    config = {
    #      :host     => grafanaHost,
    #      :port     => grafanaPort,
    #      :user     => 'admin',
    #      :password => 'admin',
    #      :debug    => false,
    #      :timeout  => 3,
    #      :ssl      => false,
    #      :url_path => '/grafana'
    #    }
    #
    #    g = Grafana::Client.new( config )
    # @return [bool, #read]
    def initialize( params = {} )

      logger.debug( params )

      host     = params[:host]     ? params[:host]     : 'localhost'
      port     = params[:port]     ? params[:port]     : 80
      user     = params[:user]     ? params[:user]     : 'admin'
      password = params[:password] ? params[:password] : ''
      urlPath  = params[:url_path] ? params[:url_path] : ''
      ssl      = params[:ssl]      ? params[:ssl]      : false

      debug    = params[:debug]    ? params[:debug]    : false
      proto    = ( ssl == true ? 'https' : 'http' )

      if( debug == true )
        logger.level = Logger::DEBUG
      end

      @apiInstance = nil
      @db          = Storage::Database.new()

      if( params.has_key?(:timeout) && params[:timeout].to_i <= 0 )
        params[:timeout] = 5
      end

      if( params.has_key?(:open_timeout) && params[:open_timeout].to_i <= 0 )
        params[:open_timeout] = 5
      end

      if( params.has_key?(:headers) && params[:headers].is_a?( Hash ) )
        params[:headers] = {}
      end

      @templateDirectory = params[:templateDirectory] ? params[:templateDirectory] : '/var/tmp/templates'

      @url  = sprintf( '%s://%s:%s%s', proto, host, port, urlPath )

      logger.debug( "Initializing API client '#{@url}'" )
      logger.debug( "Options: #{params}" )

      begin

        @apiInstance = RestClient::Resource.new(
          @url,
          :timeout      => params[:timeout],
          :open_timeout => params[:open_timeout],
          :headers      => params[:headers],
          :verify_ssl   => false
        )
      rescue => e
        logger.error( e )
      end

      @headers = nil

      logger.debug( params )

      if( params[:headers] && params[:headers].has_key?(:authorization) )
        # API key Auth
        @headers = {
          :content_type  => 'application/json; charset=UTF-8',
          :Authorization => params[:headers][:authorization]
        }
      else
        # Regular login Auth
        self.login( { :user => user, :password => password } )

        if( logger.debug( @headers ) == false )
          return nil
        end
      end

      return self
    end

    # Login into Grafana
    #
    # @param [Hash, #read] params the params to create a valid login
    # @option params [String] :user The Username
    # @option params [String] :password The Password
    # @example For an successful Login
    #    login( { :user => 'admin', :password => 'admin' } )
    # @return [bool, #read]
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

        logger.error( "Error running POST request on /login: #{e}" )
        logger.error( "Request data: #{request_data.to_json}" )

        return false
      end

      logger.debug("User session initiated")
    end


    def prepare( host )

      logger.debug( sprintf(  'prepare( %s )', host ) )

      dns = @db.dnsData( { :ip => host, :short => host } )

      if( dns != nil )
        dnsId        = dns[ :id ]
        dnsIp        = dns[ :ip ]
        dnsShortname = dns[ :shortname ]
        dnsLongname  = dns[ :longname ]
        dnsCreated   = dns[ :created ]
        dnsChecksum  = dns[ :checksum ]

        @shortHostname  = @grafanaHostname = dnsShortname

        config          = @db.config( { :ip => dnsIp, :key => 'display-name' } )

        if( config != false )
          @shortHostname = config.dig( dnsChecksum, 'display-name' ).first.to_s
        end

        @shortHostname        = @shortHostname.gsub( '.', '-' )

        @discoveryFile        = sprintf( '%s/%s/discovery.json'       , @cacheDirectory, host )
        @mergedHostFile       = sprintf( '%s/%s/mergedHostData.json'  , @cacheDirectory, host )
        @monitoringResultFile = sprintf( '%s/%s/monitoring.result'    , @cacheDirectory, host )

      end

    end


  end

end

# EOF

