module Grafana

  module HttpRequest

    def getRequest( endpoint )
      logger.info("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")

      return self.issueRequest( 'GET', endpoint )
    end

    def postRequest(endpoint, postdata={})
      logger.info("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")
      return issueRequest('POST', endpoint, postdata)
    end

    def putRequest(endpoint, putdata={})
      logger.info("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")
      return issueRequest('PUT', endpoint, putdata)
    end

    def deleteRequest(endpoint)
      logger.info("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")
      return issueRequest('DELETE', endpoint)
    end

    def patchRequest(endpoint, patchdata={})
      logger.info("Running: Grafana::HttpRequest::#{__method__} on #{endpoint}")
      return issueRequest('PATCH', endpoint, patchdata)
    end

    def issueRequest( method_type = 'GET', endpoint = '/', data = {} )

      logger.debug( "( method_type = '#{method_type}', endpoint = '#{endpoint}', data = '#{data}' )" )

      logger.debug( @headers )

      begin
        resp = nil
        case method_type.upcase
        when 'GET'
          resp = @apiInstance[endpoint].get( @headers )
        when 'POST'
          resp = @apiInstance[endpoint].post( data, @headers )
        when 'PATCH'
          resp = @apiInstance[endpoint].patch(data,@headers)
        when 'PUT'
          resp = @apiInstance[endpoint].put(data,@headers)
        when 'DELETE'
          resp = @apiInstance[endpoint].delete(@headers)
        else
          logger.error("Error: #{__method__} is not a valid request method.")
          return false
        end

        if (resp.code.to_i >= 200 && resp.code.to_i <= 299) || (resp.code.to_i >= 400 && resp.code.to_i <= 499)
          return JSON.parse(resp.body)
        else
          logger.error("#{__method__} on #{endpoint} failed: HTTP #{resp.code} - #{resp.body}")
          return false
        end

      rescue => e
       logger.error("Error: #{__method__} #{endpoint} error: #{e}")
       return false
      end

    end

  end

end

