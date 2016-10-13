#!/usr/bin/ruby
#
#
#
#

require 'rest-client'
require 'openssl'
require 'logger'
require 'json'
require 'net/http'
require 'uri'


# -------------------------------------------------------------------------------------------------------------------

class Icinga2

  attr_reader :version
  attr_reader :status

  def initialize( settings = {} )

    @logDirectory   = settings[:logDirectory]   ? settings[:logDirectory]   : '/tmp'
    @icingaHost     = settings[:icingaHost]     ? settings[:icingaHost]     : 'localhost'
    @icingaPort     = settings[:icingaPort]     ? settings[:icingaPort]     : 5665
    @icingaApiUser  = settings[:icingaApiUser]  ? settings[:icingaApiUser]  : nil
    @icingaApiPass  = settings[:icingaApiPass]  ? settings[:icingaApiPass]  : nil

    logFile        = sprintf( '%s/icinga2.log', @logDirectory )

    file           = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync      = true
    @log           = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level     = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @icingaApiUrlBase = sprintf( 'https://%s:%d', @icingaHost, @icingaPort )
    @nodeName         = Socket.gethostbyname( Socket.gethostname ).first

    version              = '1.1.0'
    date                 = '2016-09-28'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' Icinga2 Management' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Bodo Schulz' )
    @log.info( "  Backendsystem #{@icingaApiUrlBase}" )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

    @log.debug( sprintf( '  server   : %s', @icingaHost ) )
    @log.debug( sprintf( '  port     : %s', @icingaPort ) )
    @log.debug( sprintf( '  api url  : %s', @icingaApiUrlBase ) )
    @log.debug( sprintf( '  api user : %s', @icingaApiUser ) )
    @log.debug( sprintf( '  api pass : %s', @icingaApiPass ) )
    @log.debug( sprintf( '  node name: %s', @nodeName ) )

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

      @log.debug( "PKI found, using client certificates for connection to Icinga 2 API" )

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

      @log.debug( "PKI not found, using basic auth for connection to Icinga 2 API" )

      @options = {
        :user       => @icingaApiUser,
        :password   => @icingaApiPass,
        :verify_ssl => OpenSSL::SSL::VERIFY_NONE
      }

      @hasCert = false
    end

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

#    @log.debug( JSON.pretty_generate( payload ) )

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
    rescue RestClient::ExceptionWithResponse => e

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
      @log.error( e )
      
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

#      @log.info( sprintf '%d hosts in monitoring', results.count() )

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

      @log.debug( s )
      @log.debug( v.to_json )

      begin

        restClient = RestClient::Resource.new(
          URI.encode( sprintf( '%s/v1/objects/services/%s!%s', @icingaApiUrlBase, host, s ) ),
          @options
        )

        payload = {
          "templates" => [ "generic-service" ],
          "attrs"     => updateHost( v, host )
        }

        @log.debug( JSON.pretty_generate( payload ) )

        data = restClient.put(
          JSON.generate( ( payload ) ),
          @headers
        )
      rescue RestClient::ExceptionWithResponse => e

        error  = JSON.parse( e.response )

        @log.error( error )

      end

    end

  end

end

# EOF
