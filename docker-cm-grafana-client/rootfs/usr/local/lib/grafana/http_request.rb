module Grafana

  module HttpRequest

    # HTTP GET Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def getRequest( endpoint )

#       logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'GET', endpoint )
    end

    # HTTP POST Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def postRequest( endpoint, postdata = {} )

#      logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'POST', endpoint, postdata )
    end

    # HTTP PUT Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def putRequest( endpoint, putdata = {} )

#       logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'PUT', endpoint, putdata )
    end

    # HTTP DELETE Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def deleteRequest( endpoint )

#       logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'DELETE', endpoint )
    end

    # HTTP PATCH Request
    #
    # @param [String, #read] endpoint URL for a HTTP Request
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def patchRequest( endpoint, patchdata = {} )

#       logger.debug("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

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

      resultCodes = {
        200 => 'created',
        400 => 'Errors (invalid json, missing or invalid fields, etc)',
        401 => 'Unauthorized',
        412 => 'Precondition failed'
      }

      begin
        response = nil
        case methodType.upcase
        when 'GET'
          response = @apiInstance[endpoint].get( @headers )
        when 'POST'
          response = @apiInstance[endpoint].post( data, @headers )
        when 'PATCH'
          response = @apiInstance[endpoint].patch( data, @headers )
        when 'PUT'
          response = @apiInstance[endpoint].put( data, @headers )
        when 'DELETE'
          response = @apiInstance[endpoint].delete( @headers )
        else
          logger.error( "Error: #{__method__} is not a valid request method." )
          return false
        end

        responseCode = response.code.to_i
        responseBody = response.body

        if( ( responseCode >= 200 && responseCode <= 299 ) || ( responseCode >= 400 && responseCode <= 499 ) )

          begin
            result            = JSON.parse( responseBody )

            if( result['status'] )
              result['message'] = result.dig( 'status' )
              result['status']  = response.code.to_i
            end
          rescue => e

            logger.error( e )
          end

          return result
        else

          logger.error( "#{__method__} #{methodType.upcase} on #{endpoint} failed: HTTP #{response.code} - #{responseBody}" )

          return JSON.parse( responseBody )
        end

      rescue => e

#        logger.error( "Error: #{__method__} #{methodType.upcase} on #{endpoint} error: '#{e}'" )
#
#        result           = JSON.parse( e.response )
#        result['status'] = e.to_s.split( ' ' ).first
#
#        return result
      end

    end

  end

end

