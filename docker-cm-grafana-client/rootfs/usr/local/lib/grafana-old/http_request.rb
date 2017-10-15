
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

#    private
    # Request executor - Private Function
    #
    # @private
    # @param [String, #read] methodType
    # @param [String, #read] endpoint
    # @param [Hash, #read] data
    # @return [Mixed, #read]  return false at Error, or an JSON on success
    def issueRequest( methodType = 'GET', endpoint = '/', data = {} )

      logger.debug( "issueRequest( #{methodType}, #{endpoint}, data )" )
      logger.debug( "#{@headers}" )

      logger.debug(@api_instance.inspect)
      logger.debug(@loggedIn)

      raise 'try first login()' if @api_instance.nil?

      @loggedIn = login( { :user => @user, :password => @password } )

      begin
        response = nil
        case methodType.upcase
        when 'GET'
          response = @api_instance[endpoint].get( @headers )
        when 'POST'

#          @loggedIn = login( { :user => @user, :password => @password } )

          # response = @api_instance[endpoint].post( data, @headers )
          @api_instance[endpoint].post( data, @headers ) do |response, request, result|

              response_body = response.body
              response_code = response.code.to_i

              logger.debug('----------------------------------------')
              logger.debug( response.inspect )
              logger.debug( response_body )
              logger.debug( response_code )
              logger.debug('----------------------------------------')

            case response.code
            when 200
              response_body = response.body
              response_code = response.code.to_i
              response_body = JSON.parse(response_body) if response_body.is_a?(String)
#
#               logger.debug('----------------------------------------')
#               logger.debug( response.inspect )
#               logger.debug( response_body )
#               logger.debug( response_code )
#               logger.debug('----------------------------------------')

              return {
                'status' => response_code,
                'message' => response_body.dig('message').nil? ? 'Successful' : response_body.dig('message')
              }
            when 400
              response_body = response.body
              response_code = response.code.to_i

#               logger.debug('----------------------------------------')
#               logger.debug( response.inspect )
#               logger.debug( response_body )
#               logger.debug( response_code )
#               logger.debug('----------------------------------------')

              raise RestClient::BadRequest

            when 403
              response_body = response.body
              response_code = response.code.to_i

#               logger.debug('----------------------------------------')
#               logger.debug( response.inspect )
#               logger.debug( response_body )
#               logger.debug( response_code )
#               logger.debug('----------------------------------------')

              raise RestClient::Forbidden

            else
              response.return!(request, result)
            end
          end

        when 'PATCH'
          response = @api_instance[endpoint].patch( data, @headers )
        when 'PUT'
          # response = @api_instance[endpoint].put( data, @headers )
          @api_instance[endpoint].put( data, @headers ) do |response, request, result|

            case response.code
            when 200
              response_body = response.body
              response_code = response.code.to_i
              response_body = JSON.parse(response_body) if response_body.is_a?(String)

              return {
                'status' => response_code,
                'message' => response_body.dig('message').nil? ? 'Successful' : response_body.dig('message')
              }
            when 400
              response_body = response.body
              response_code = response.code.to_i
              raise RestClient::BadRequest

            when 403
              response_body = response.body
              response_code = response.code.to_i
              raise RestClient::Forbidden

            else
              response.return!(request, result)
            end
          end

        when 'DELETE'
          response = @api_instance[endpoint].delete( @headers )
        else
          logger.error( "Error: #{__method__} is not a valid request method." )
          return false
        end

        responseCode = response.code.to_i
        responseBody = response.body

        if( ( responseCode >= 200 && responseCode <= 299 ) || ( responseCode >= 400 && responseCode <= 499 ) )

          begin

            result = JSON.parse( responseBody )

            if( result.is_a?( Hash ) )

              resultStatus = result.dig('status')

              if( resultStatus != nil )
                result['message'] = resultStatus
                result['status']  = response.code.to_i
              end
            end

          rescue => e

            logger.error( e )

            result = false
          end

          return result
        else

          logger.error( "#{__method__} #{methodType.upcase} on #{endpoint} failed: HTTP #{response.code} - #{responseBody}" )

          return JSON.parse( responseBody )
        end
      rescue RestClient::BadRequest

        response_body = JSON.parse(response_body) if response_body.is_a?(String)

        return {
          'status' => 400,
          'message' => response_body.dig('message').nil? ? 'Bad Request' : response_body.dig('message')
        }

      rescue RestClient::Unauthorized

        return {
          'status' => 401,
          'message' => format('Not authorized to connect \'%s/%s\' - wrong username or password?', @url, endpoint)
        }

      rescue RestClient::Forbidden => e

        logger.error( "Error: #{__method__} #{methodType.upcase} on #{endpoint} error: '#{e.inspect}'" )

        return {
          'status' => 403,
          'message' => format('access for \'%s\' is forbidden', endpoint)
        }

      rescue RestClient::ExceptionWithResponse => e

        logger.error( "Error: #{__method__} #{methodType.upcase} on #{endpoint} error: '#{e}'" )
        return false
      end

    end

  end

end

