
module Grafana

  module Organizations

    def allOrgs()
      endpoint = "/api/orgs"
      @logger.info("Getting all organizations (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end


    def updateOrg(org_id, properties={})
      endpoint = "/api/orgs/#{org_id}"
      @logger.info("Updating orgnaization ID #{org_id} (POST #{endpoint})") if @debug
      return postRequest(endpoint, properties)
    end

    def orgUsers(org_id)
      endpoint = "/api/orgs/#{org_id}/users"
      @logger.info("Getting users in orgnaization ID #{org_id} (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end


    def addUserToOrg(org_id, user={})
      endpoint = "/api/orgs/#{org_id}/users"
      @logger.info("Adding user to orgnaization ID #{org_id} (POST #{endpoint})") if @debug
      return postRequest(endpoint, user)
    end

    def updateOrgUser(org_id, user_id, properties={})
      endpoint = "/api/orgs/#{org_id}/users/#{user_id}"
      @logger.info("Updating user #{user_id} in organization #{org_id} (PATCH #{endpoint})") if @debug
      return patchRequest(endpoint, properties)
    end

    def deleteUserFromOrg(org_id, user_id)
      endpoint = "/api/orgs/#{org_id}/users/#{user_id}"
      @logger.info("Deleting user #{user_id} in organization #{org_id} (DELETE #{endpoint})") if @debug
      return deleteRequest(endpoint)
    end

  end

end
