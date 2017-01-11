
module Grafana

  module Organization

    def currentOrganization()
      endpoint = "/api/org"
      @logger.info("Getting current organization (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def updateCurrentOrganization(properties={})
      endpoint = "/api/org"
      @logger.info("Updating current organization (PUT #{endpoint})") if @debug
      return putRequest(endpoint, properties)
    end

    def currentOrganizationUsers()
      endpoint = "/api/org/users"
      @logger.info("Getting organization users (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def addUserToCurrentOrganization( properties = {} )
      endpoint = "/api/org/users"
      @logger.info("Adding user to current organization (POST #{endpoint})") if @debug
      return postRequest(endpoint, properties)
    end


  end

end
