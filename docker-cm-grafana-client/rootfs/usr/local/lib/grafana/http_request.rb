module Grafana

  module HttpRequest

    # HTTP GET Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def getRequest( endpoint )

      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'GET', endpoint )
    end

    # HTTP POST Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def postRequest( endpoint, postdata = {} )

      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'POST', endpoint, postdata )
    end

    # HTTP PUT Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def putRequest( endpoint, putdata = {} )
      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'PUT', endpoint, putdata )
    end

    # HTTP DELETE Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def deleteRequest( endpoint )

      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'DELETE', endpoint )
    end

    # HTTP PATCH Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def patchRequest( endpoint, patchdata = {} )

      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'PATCH', endpoint, patchdata )
    end

    # Request executor - Private Function
    #
    # @private
    # @param [String, #read] methodType
    # @param [String, #read] endpoint
    # @param [Hash, #read] data
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def issueRequest( methodType = 'GET', endpoint = '/', data = {} )

      logger.debug( "( methodType = '#{methodType}', endpoint = '#{endpoint}', data = '#{data}' )" )

      logger.debug( @headers )

      begin
        resp = nil
        case methodType.upcase
        when 'GET'
          resp = @apiInstance[endpoint].get( @headers )
        when 'POST'
          resp = @apiInstance[endpoint].post( data, @headers )
        when 'PATCH'
          resp = @apiInstance[endpoint].patch( data, @headers )
        when 'PUT'
          resp = @apiInstance[endpoint].put( data, @headers )
        when 'DELETE'
          resp = @apiInstance[endpoint].delete( @headers )
        else
          logger.error( "Error: #{__method__} is not a valid request method." )
          return false
        end

        if( ( resp.code.to_i >= 200 && resp.code.to_i <= 299 ) || ( resp.code.to_i >= 400 && resp.code.to_i <= 499 ) )
          return JSON.parse( resp.body )
        else
          logger.error( "#{__method__} on #{endpoint} failed: HTTP #{resp.code} - #{resp.body}" )
          return false
        end

      rescue => e
       logger.error( "Error: #{__method__} #{endpoint} error: #{e}" )
       return false
      end

    end

  end

end

