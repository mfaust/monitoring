
# -----------------------------------------------------------------------------

module ExternalDiscovery

  class MonitoringClient

    include Logging

    attr_reader :monitoringData

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

      begin

        @monitoringData   = Hash.new()

        # run internal scheduler to remove old data
        scheduler = Rufus::Scheduler.new

        scheduler.every( 45, :first_in => 5 ) do
          self.getNodes()
        end
      rescue => e

        logger.error( e )
        raise e

      end

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

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => e.code,
          :message => e.message
        }

      rescue => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => 500,
          :message => e.message
        }

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
        response  = restClient.delete()

        data   = JSON.parse( response )

        return data

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => e.code,
          :message => e.message
        }

      rescue => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => 500,
          :message => e.message
        }

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

      begin

        response = restClient.post( tags )

        data   = JSON.parse( response )

        logger.debug( data )

        return data

      rescue RestClient::Exceptions::ReadTimeout => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => e.code,
          :message => e.message
        }

      rescue RestClient::ExceptionWithResponse => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => e.code,
          :message => e.message
        }

      rescue => e

        logger.error( e.inspect )
        logger.error( e.message )
        logger.error( e.code )

        return {
          :status  => 500,
          :message => e.message
        }

      end

    end


    def getNodes()

      logger.info( 'get Monitoring data' )
      start = Time.now

      url = sprintf( '%s/host', @apiUrl )

      begin

        response     = RestClient.get( url, params: { 'short': true } )

        responseCode = response.code
        responseBody = response.body

        if( responseCode == 200 )

          data   = JSON.parse( responseBody )

          @monitoringData = data.dig('hosts')

        else

          logger.debug( responseCode )
          logger.debug( responseBody )

          @monitoringData = {}

        end

      rescue Exception => e

        logger.error( e )
        logger.error( e.backtrace )

        @monitoringData = {}

      end

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

    end

  end

end

# ---------------------------------------------------------------------------------------
# EOF
