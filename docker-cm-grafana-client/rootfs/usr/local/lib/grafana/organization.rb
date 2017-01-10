
module Grafana

  module Organization

    def current_org()
      endpoint = "/api/org"
      @logger.info("Getting current organization (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def update_current_org(properties={})
      endpoint = "/api/org"
      @logger.info("Updating current organization (PUT #{endpoint})") if @debug
      return putRequest(endpoint, properties)
    end

    def current_org_users()
      endpoint = "/api/org/users"
      @logger.info("Getting organization users (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def add_user_to_current_org(properties={})
      endpoint = "/api/org/users"
      @logger.info("Adding user to current organization (POST #{endpoint})") if @debug
      return postRequest(endpoint, properties)
    end


  end

end
