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

require_relative 'icinga/application'
require_relative 'icinga/host'
require_relative 'icinga/service'

# -------------------------------------------------------------------------------------------------------------------

module Icinga

  class Client

    include Logging
    include Icinga::Application
    include Icinga::Host
    include Icinga::Service

    def initialize( params = {} )

      @logDirectory   = params[:logDirectory]   ? params[:logDirectory]   : '/tmp'
      @icingaHost     = params[:icingaHost]     ? params[:icingaHost]     : 'localhost'
      @icingaPort     = params[:icingaPort]     ? params[:icingaPort]     : 5665
      @icingaApiUser  = params[:icingaApiUser]  ? params[:icingaApiUser]  : nil
      @icingaApiPass  = params[:icingaApiPass]  ? params[:icingaApiPass]  : nil

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

      @hasCert = false

      checkCert()

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }
    end


    def checkCert()

      # check whether pki files are there, otherwise use basic auth
      if File.file?( sprintf( 'pki/%s.crt', @nodeName ) )

        logger.debug( "PKI found, using client certificates for connection to Icinga 2 API" )

        sslCertFile = File.read( sprintf( 'pki/%s.crt', @nodeName ) )
        sslKeyFile  = File.read( sprintf( 'pki/%s.key', @nodeName ) )
        sslCAFile   = File.read( 'pki/ca.crt' )

        cert      = OpenSSL::X509::Certificate.new( sslCertFile )
        key       = OpenSSL::PKey::RSA.new( sslKeyFile )

        @options   = {
          :ssl_client_cert => cert,
          :ssl_client_key  => key,
          :ssl_ca_file     => sslCAFile,
          :verify_ssl      => OpenSSL::SSL::VERIFY_NONE
        }

        @hasCert = true
      else

        logger.debug( "PKI not found, using basic auth for connection to Icinga 2 API" )

        @options = {
          :user       => @icingaApiUser,
          :password   => @icingaApiPass,
          :verify_ssl => OpenSSL::SSL::VERIFY_NONE
        }

        @hasCert = false
      end

    end





  end
end
# EOF
