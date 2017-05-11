
require 'json'
require 'rest-client'

require_relative '../logging'

# -----------------------------------------------------------------------------

module ExternalDiscovery

  class MonitoringClient

    include Logging

    def initialize( settings )

      @apiHost    = settings.dig(:monitoring, :host)    || 'localhost'
      @apiPort    = settings.dig(:monitoring, :port)    || 80
      @apiVersion = settings.dig(:monitoring, :version) || 2
      @apiUrl     = settings.dig(:monitoring, :url)

      @headers     = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      }

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - External Discovery Service - Monitoring NetworkClient' )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

    end


    def fetch( path = '/' )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )

      begin

        response     = restClient.get( @headers )

        responseCode = response.code
        responseBody = response.body

# logger.debug( response.class.to_s )
# logger.debug( response.inspect )
# logger.debug( response )
#
# logger.debug( responseCode )
# logger.debug( responseBody )

        if( responseCode == 200 )

          data   = JSON.parse( responseBody )

          return data

        elsif( responseCode == 204 )

          return { 'status' => responseCode }

        end

      rescue Exception => e

        logger.error( e )
        return nil
      end

    end


    def remove( path )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url )
      )

      payload = {
        "force" => true
      }

      begin
        data   = restClient.delete()
        data   = JSON.parse( data )

        return data

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        return nil
      end

    end


    def add( path, tags = {} )

      logger.debug( "add( #{path}, #{tags} )" )

      url = sprintf( '%s/host/%s', @apiUrl, path )

      restClient = RestClient::Resource.new(
        URI.encode( url ),
        :timeout      => 25,
        :open_timeout => 15,
      )
#
# logger.debug( tags )

      begin
        data   = restClient.post( tags )
        data   = JSON.parse( data )

        logger.debug( data )

        return data

      rescue RestClient::Exceptions::ReadTimeout => e

        logger.error( e.inspect )
        logger.error( e.message )

        return {
          :status  => 408,
          :message => e.message
        }

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        logger.error( e.message )

        return {
          :status  => 500,
          :message => e.message
        }

      rescue => e

        logger.error( e.inspect )

        return nil
      end

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
