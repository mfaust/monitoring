#!/usr/bin/ruby
#
#
#
#

require 'rest-client'
require 'openssl'

require 'json'
require 'net/http'
require 'uri'

require_relative 'logging'
require_relative 'icinga/http_request'
require_relative 'icinga/application'
require_relative 'icinga/host'
require_relative 'icinga/service'

# -------------------------------------------------------------------------------------------------------------------

module Icinga

  class Client

    include Logging

    include Icinga::HttpRequest
    include Icinga::Application
    include Icinga::Host
    include Icinga::Service

    def initialize( params = {} )

      @icingaHost     = params[:icingaHost]     ? params[:icingaHost]     : 'localhost'
      @icingaPort     = params[:icingaPort]     ? params[:icingaPort]     : 5665
      @icingaApiUser  = params[:icingaApiUser]  ? params[:icingaApiUser]  : nil
      @icingaApiPass  = params[:icingaApiPass]  ? params[:icingaApiPass]  : nil

      timeout         = 10
      openTimeout     = 10

      @icingaApiUrlBase = sprintf( 'https://%s:%d', @icingaHost, @icingaPort )
      @nodeName         = Socket.gethostbyname( Socket.gethostname ).first

      version              = '1.3.0-dev'
      date                 = '2017-01-15'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' Icinga2 Management' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Bodo Schulz' )
      logger.info( "  Backendsystem #{@icingaApiUrlBase}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      logger.debug( sprintf( '  server   : %s', @icingaHost ) )
      logger.debug( sprintf( '  port     : %s', @icingaPort ) )
      logger.debug( sprintf( '  api url  : %s', @icingaApiUrlBase ) )
      logger.debug( sprintf( '  api user : %s', @icingaApiUser ) )
      logger.debug( sprintf( '  api pass : %s', @icingaApiPass ) )
      logger.debug( sprintf( '  node name: %s', @nodeName ) )

      begin

        @apiInstance = RestClient::Resource.new(
          @icingaApiUrlBase,
          :timeout      => timeout,
          :open_timeout => openTimeout,
          :headers      => @headers,
          :verify_ssl   => false
        )
      rescue => e
        logger.error( e )
      end

      @hasCert =  self.checkCert( { :nodeName => @nodeName, :user => @icingaApiUser, :password => @icingaApiPass } )

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }

      if( @hasCert == true )

      else
        # Regular login Auth
        self.login( { :user => @icingaApiUser, :password => @icingaApiPass } )

        if( logger.debug( @headers ) == false )
          return nil
        end
      end

      return self

    end


    def checkCert( params = {} )

      nodeName     = params[:nodeName]       ? params[:nodeName]       : 'localhost'

      user         = params[:user]           ? params[:user]           : 'admin'
      password     = params[:password]       ? params[:password]       : ''

      # check whether pki files are there, otherwise use basic auth
      if File.file?( sprintf( 'pki/%s.crt', nodeName ) )

        logger.debug( "PKI found, using client certificates for connection to Icinga 2 API" )

        sslCertFile = File.read( sprintf( 'pki/%s.crt', nodeName ) )
        sslKeyFile  = File.read( sprintf( 'pki/%s.key', nodeName ) )
        sslCAFile   = File.read( 'pki/ca.crt' )

        cert      = OpenSSL::X509::Certificate.new( sslCertFile )
        key       = OpenSSL::PKey::RSA.new( sslKeyFile )

        @options   = {
          :ssl_client_cert => cert,
          :ssl_client_key  => key,
          :ssl_ca_file     => sslCAFile,
          :verify_ssl      => OpenSSL::SSL::VERIFY_NONE
        }

        return true
      else

        logger.debug( "PKI not found, using basic auth for connection to Icinga 2 API" )

        @options = {
          :user       => user,
          :password   => password,
          :verify_ssl => OpenSSL::SSL::VERIFY_NONE
        }

        return false
      end

    end


    # Login into Icinga
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
        resp = @apiInstance['/'].post(
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

        logger.error( "Error running POST request on /: #{e}" )
        logger.error( "Request data: #{request_data.to_json}" )

        return false
      end

      logger.debug("User session initiated")
    end


    def run()


    end

  end
end
# EOF
