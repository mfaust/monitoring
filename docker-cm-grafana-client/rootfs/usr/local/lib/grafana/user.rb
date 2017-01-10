
module Grafana

  module User

    def current_user()
      endpoint = "/api/user"
      @logger.info("Getting user current user (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def update_current_user_pass(properties={})
      endpoint = "/api/user/password"
      @logger.info("Updating current user password (PUT #{endpoint})") if @debug
      return putRequest(endpoint,properties)
    end

    def switch_current_user_org(org_id)
      endpoint = "/api/user/using/#{org_id}"
      @logger.info("Switching current user to Org ID #{id} (GET #{endpoint})") if @debug
      return postRequest(endpoint, {})
    end

    def current_user_orgs()
      endpoint = "/api/user/orgs"
      @logger.info("Getting current user organizations (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def add_dashboard_star(dashboard_id)
      endpoint = "/api/user/stars/dashboard/#{dashboard_id}"
      @logger.info("Adding start to dashboard ID #{dashboard_id} (GET #{endpoint})") if @debug
      return postRequest(endpoint, {})
    end

    def remove_dashboard_star(dashboard_id)
      endpoint = "/api/user/stars/dashboard/#{dashboard_id}"
      @logger.info("Deleting start on dashboard ID #{dashboard_id} (GET #{endpoint})") if @debug
      return deleteRequest(endpoint)
    end

  end

end
