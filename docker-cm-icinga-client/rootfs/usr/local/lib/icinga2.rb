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

# -------------------------------------------------------------------------------------------------------------------

Module Icinga

  class Client

    include Logging

    def initialize( settings = {} )

      @logDirectory   = settings[:logDirectory]   ? settings[:logDirectory]   : '/tmp'
      @icingaHost     = settings[:icingaHost]     ? settings[:icingaHost]     : 'localhost'
      @icingaPort     = settings[:icingaPort]     ? settings[:icingaPort]     : 5665
      @icingaApiUser  = settings[:icingaApiUser]  ? settings[:icingaApiUser]  : nil
      @icingaApiPass  = settings[:icingaApiPass]  ? settings[:icingaApiPass]  : nil

      logFile        = sprintf( '%s/icinga2.log', @logDirectory )

      @icingaApiUrlBase = sprintf( 'https://%s:%d', @icingaHost, @icingaPort )
      @nodeName         = Socket.gethostbyname( Socket.gethostname ).first
      @MQSettings = {
        :beanstalkHost => mqHost,
        :beanstalkPort => mqPort
      }

      version              = '1.1.0'
      date                 = '2016-09-28'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' Icinga2 Management' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016 Bodo Schulz' )
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


    # Message-Queue Integration
    #
    #
    #
    def queue()

      c = MessageQueue::Consumer.new( @MQSettings )

      threads = Array.new()

      threads << Thread.new {

        self.processQueue(
          c.getJobFromTube( @mqQueue )
        )
      }

      threads.each { |t| t.join }

    end


    def processQueue( data = {} )

      if( data.count != 0 )

        logger.info( sprintf( 'process Message from Queue %s: %d', data.dig(:tube), data.dig(:id) ) )

        command = data.dig( :body, 'cmd' )     || nil
        node    = data.dig( :body, 'node' )    || nil
        payload = data.dig( :body, 'payload' ) || nil

        if( command == nil )
          logger.error( 'wrong command' )
          logger.error( data )
          return
        end

        if( node == nil || payload == nil )
          logger.error( 'missing node or payload' )
          logger.error( data )
          return
        end

        result = {
          :status  => 400,
          :message => sprintf( 'wrong command detected: %s', command )
        }


        logger.debug( data )
        logger.debug( data.dig( :body, 'payload' ) )

        tags     = data.dig( :body, 'payload', 'tags' )
        overview = data.dig( :body, 'payload', 'overview' ) || true

        case command
        when 'add'
#           logger.info( sprintf( 'add node %s', node ) )

          # TODO
          # check payload!
          # e.g. for 'force' ...
          result = self.createDashboardForHost( { :host => node, :tags => tags, :overview => overview } )

          logger.info( result )
        when 'remove'
#           logger.info( sprintf( 'remove dashboards for node %s', node ) )
          result = self.deleteDashboards( { :host => node } )

          logger.info( result )
        when 'info'
#           logger.info( sprintf( 'give dashboards for %s back', node ) )
          result = self.listDashboards( { :host => node } )
        else
          logger.error( sprintf( 'wrong command detected: %s', command ) )

          result = {
            :status  => 400,
            :message => sprintf( 'wrong command detected: %s', command )
          }

          logger.info( result )
        end

        result[:request]    = data

#         self.sendMessage( result )
      end

    end


    def sendMessage( data = {} )

    logger.debug( JSON.pretty_generate( data ) )

    p = MessageQueue::Producer.new( @MQSettings )

    job = {
      cmd:  'information',
      from: 'discovery',
      payload: data
    }.to_json

    logger.debug( p.addJob( 'mq-information', job ) )

  end




    def applicationData()

      apiUrl     = sprintf( '%s/v1/status/IcingaApplication', @icingaApiUrlBase )
      restClient = RestClient::Resource.new( URI.encode( apiUrl ), @options )
      data       = JSON.parse( restClient.get( @headers ).body )
      result     = data['results'][0]['status'] # there's only one row

      return result

    end


    def addHost( host, vars = {} )

      status      = 0
      name        = host
      message     = 'undefined'

      @headers['X-HTTP-Method-Override'] = 'PUT'

      # build FQDN
      fqdn = Socket.gethostbyname( host ).first

      payload = {
        "templates" => [ "generic-host" ],
        "attrs" => {
          "address"      => fqdn,
          "display_name" => host
        }
      }

      if( ! vars.empty? )
        payload['attrs']['vars'] = vars
      end

  #    logger.debug( JSON.pretty_generate( payload ) )

      restClient = RestClient::Resource.new(
        URI.encode( sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ) ),
        @options
      )

      begin
        data = restClient.put(
          JSON.generate( payload ),
          @headers
        )

        data   = JSON.parse( data )
        result = data['results'][0] ? data['results'][0] : nil

        if( result != nil )

          status  = 200
          name    = host
          message = result['status']

        end

      rescue RestClient::ExceptionWithResponse => e

        error  = JSON.parse( e.response )

        if( error['results'] )

          result  = error['results'][0] ? error['results'][0] : error
          status  = result['code'].to_i
          message = result['status']
        else

          status  = error['error'].to_i
          message = error['status']
        end

        status      = status
        name        = host
        message     = message

      end

      @status = status

      result = {
        :status      => status,
        :name        => name,
        :message     => message
      }

      return result

    end

    # TODO
    # funktioniert nur, wenn der Host bereits existiert
    def deleteHost( host )

      status      = 0
      name        = host
      message     = 'undefined'

      @headers['X-HTTP-Method-Override'] = 'DELETE'

      restClient = RestClient::Resource.new(
        URI.encode( sprintf( '%s/v1/objects/hosts/%s?cascade=1', @icingaApiUrlBase, host ) ),
        @options
      )

      begin
        data   = restClient.get( @headers )
        data   = JSON.parse( data )
        result = data['results'][0] ? data['results'][0] : nil

        if( result != nil )

          status  = 200
          name    = host
          message = result['status']

        end
      rescue => e

        # TODO
        # bessere fehlerbehandlung, hier kommt es immer mal wieder zu problemen!
        error  = JSON.parse( e.response )

        if( error['results'] )

          result  = error['results'][0] ? error['results'][0] : error
          status  = result['code'].to_i
          message = result['status']
        else

          status  = error['error'].to_i
          message = error['status']
        end

        status      = status
        name        = host
        message     = message

      rescue e
        logger.error( e )

      end

      @status = status

      result = {
        :status      => status,
        :name        => name,
        :message     => message
      }

      return result

    end


    def listHost( host = nil )

      code        = nil
      result      = {}

      @headers.delete( 'X-HTTP-Method-Override' )

      restClient = RestClient::Resource.new(
        URI.encode( sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ) ),
        @options
      )

      begin
        data     = restClient.get( @headers )

        results  =  JSON.parse( data.body )['results']

  #      logger.info( sprintf '%d hosts in monitoring', results.count() )

        result[:status] = 200

        results.each do |r|

          attrs = r['attrs'] ?  r['attrs'] : nil

          result[attrs['name']] = {
            :name         => attrs['name'],
            :display_name => attrs['display_name'],
            :type         => attrs['type']
          }

        end

      rescue => e

        error = JSON.parse( e.response )

        result = {
          :status      => error['error'].to_i,
          :name        => host,
          :message     => error['status']
        }
      end

      return result
    end


    def addServices( host, services = {} )

      def updateHost( hash, host )

        hash.each do |k, v|
          if k == "host" && v.is_a?( String )
            v.replace( host )
          elsif v.is_a?( Hash )
            updateHost( v, host )
          elsif v.is_a?(Array)
            v.flatten.each { |x| updateHost( x, host ) if x.is_a?(Hash) }
          end
        end

        hash
      end

      fqdn = Socket.gethostbyname( host ).first

      restClient = RestClient::Resource.new(
        URI.encode( sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ) ),
        @options
      )

      services.each do |s,v|

        logger.debug( s )
        logger.debug( v.to_json )

        begin

          restClient = RestClient::Resource.new(
            URI.encode( sprintf( '%s/v1/objects/services/%s!%s', @icingaApiUrlBase, host, s ) ),
            @options
          )

          payload = {
            "templates" => [ "generic-service" ],
            "attrs"     => updateHost( v, host )
          }

          logger.debug( JSON.pretty_generate( payload ) )

          data = restClient.put(
            JSON.generate( ( payload ) ),
            @headers
          )
        rescue RestClient::ExceptionWithResponse => e

          error  = JSON.parse( e.response )

          logger.error( error )

        end

      end

    end

  end
end
# EOF
