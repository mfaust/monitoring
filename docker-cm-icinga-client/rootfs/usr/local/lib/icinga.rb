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
require_relative 'message-queue'
require_relative 'icinga/network'
require_relative 'icinga/status'
require_relative 'icinga/host'
require_relative 'icinga/service'
require_relative 'icinga/message-queue'

# -------------------------------------------------------------------------------------------------------------------

module Icinga

  class Client

    include Logging

    include Icinga::Network
    include Icinga::Status
    include Icinga::Host
    include Icinga::Service
    include Icinga::Queue

    def initialize( params = {} )

      @icingaHost       = params[:icingaHost]      ? params[:icingaHost]       : 'localhost'
      @icingaApiPort    = params[:icingaApiPort]   ? params[:icingaApiPort]    : 5665
      @icingaApiUser    = params[:icingaApiUser]   ? params[:icingaApiUser]    : nil
      @icingaApiPass    = params[:icingaApiPass]   ? params[:icingaApiPass]    : nil
      @icingaCluster    = params[:icingaCluster]   ? params[:icingaCluster]    : false
      @icingaSatellite  = params[:icingaSatellite] ? params[:icingaSatellite]  : nil
      mqHost            = params[:mqHost]          ? params[:mqHost]           : 'localhost'
      mqPort            = params[:mqPort]          ? params[:mqPort]           : 11300
      @mqQueue          = params[:mqQueue]         ? params[:mqQueue]          : 'mq-icinga'

      @icingaApiUrlBase = sprintf( 'https://%s:%d', @icingaHost, @icingaApiPort )
      @nodeName         = Socket.gethostbyname( Socket.gethostname ).first

      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      version              = '1.3.3-dev'
      date                 = '2017-02-07'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' Icinga2 Management' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Bodo Schulz' )
      logger.info( "  Backendsystem #{@icingaApiUrlBase}" )
      logger.info( sprintf( '    cluster enabled: %s', @icingaCluster ? 'true' : 'false' ) )
      if( @icingaCluster )
        logger.info( sprintf( '    satellite endpoint: %s', @icingaSatellite ) )
      end
      logger.info( '  used Services:' )
      logger.info( "    - message Queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      logger.debug( sprintf( '  server   : %s', @icingaHost ) )
      logger.debug( sprintf( '  port     : %s', @icingaApiPort ) )
      logger.debug( sprintf( '  api url  : %s', @icingaApiUrlBase ) )
      logger.debug( sprintf( '  api user : %s', @icingaApiUser ) )
      logger.debug( sprintf( '  api pass : %s', @icingaApiPass ) )
      logger.debug( sprintf( '  node name: %s', @nodeName ) )

      @hasCert   = self.checkCert( { :user => @icingaApiUser, :password =>  @icingaApiPass } )
      @headers   = { "Content-Type" => "application/json", "Accept" => "application/json" }

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



    def run()

      return

#      vars = {
#        'coremedia' => {
#          'cae-preview': {
#            'port': 40000,
#            'jmx': true
#          },
#          'master-live-server': {
#            'port': 40299,
#            'port_http': 40280,
#            'ior': true,
#            'runlevel': true,
#            'license': true
#          }
#        }
#      }

      vars = {
        "coremedia" => {

          "adobe-drive-server": {
            "port": 41199,
            "description": "Adobe Drive Server",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          },
          "cae-live-1": {
            "port": 42199,
            "description": "CAE Live 1",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          },
          "cae-preview": {
            "port": 40999,
            "description": "CAE Preview",
            "cap_connection": true,
            "uapi_cache": true
          },
          "caefeeder-live": {
            "port": 40899,
            "description": "CAEFeeder Live",
            "feeder": "live",
            "cap_connection": true,
            "uapi_cache": true
          },
          "caefeeder-preview": {
            "port": 40799,
            "description": "CAEFeeder Preview",
            "feeder": "preview",
            "cap_connection": true,
            "uapi_cache": true
          },
          "content-feeder": {
            "port": 40499,
            "description": "Content Feeder",
            "feeder": "content",
            "cap_connection": true,
            "uapi_cache": true
          },
          "content-management-server": {
            "port": 40199,
            "description": "Content Management Server",
            "port_http": 40180,
            "ior": true,
            "runlevel": true,
            "license": true
          },
          "elastic-worker": {
            "port": 40699,
            "description": "Elastic Worker",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          },
          "master-live-server": {
            "port": 40299,
            "description": "Master Live Server",
            "port_http": 40280,
            "ior": true,
            "runlevel": true,
            "license": true
          },
          "mongodb": {
            "port": 28017,
            "description": "MongoDB"
          },
          "mysql": {
            "port": 3306,
            "description": "MySQL"
          },
          "replication-live-server": {
            "port": 42099,
            "description": "RLS",
            "port_http": 42080,
            "ior": true,
            "runlevel": true,
            "license": true
          },
          "sitemanager": {
            "port": 41399,
            "description": "Site Manager"
          },
          "solr-master": {
            "port": 40099,
            "description": "Solr Master",
            "cores": [
              "live",
              "preview",
              "studio"
            ]
          },
          "studio": {
            "port": 41099,
            "description": "Studio",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          },
          "user-changes": {
            "port": 40599,
            "description": "User Changes",
            "cap_connection": true,
            "uapi_cache": true
          },
          "workflow-server": {
            "port": 40399,
            "description": "Workflow Server",
            "cap_connection": true,
            "uapi_cache": true,
            "blob_cache": true
          }
        }
      }

#      logger.debug( self.deleteHost( { :host => 'monitoring-16-01' } ) )
#      logger.debug( self.addHost( { :host => 'monitoring-16-01', :vars => vars } ) )
#      logger.debug( self.addHost( { :host => 'moebius-ci-01' } ) )
#      logger.debug( self.addHost( { :host => 'moebius-ci-02' } ) )
#      logger.debug( self.applicationData() )
#      logger.debug( self.listHost( { :host => 'monitoring-16-01' } ) )
#      logger.debug( self.listHost() )

    end

  end
end
# EOF
