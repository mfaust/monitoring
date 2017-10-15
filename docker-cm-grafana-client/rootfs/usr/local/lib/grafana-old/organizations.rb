
module Grafana

  module Organizations

    def allOrganizations()
      endpoint = "/api/orgs"
      @logger.info("Getting all organizations (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end


    def updateOrganization(org_id, properties={})
      endpoint = "/api/orgs/#{org_id}"
      @logger.info("Updating orgnaization ID #{org_id} (POST #{endpoint})") if @debug
      return postRequest(endpoint, properties)
    end


    def organizationUsers(org_id)
      endpoint = "/api/orgs/#{org_id}/users"
      @logger.info("Getting users in orgnaization ID #{org_id} (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end


    def addUserToOrganization(org_id, user={})
      endpoint = "/api/orgs/#{org_id}/users"
      @logger.info("Adding user to orgnaization ID #{org_id} (POST #{endpoint})") if @debug
      return postRequest(endpoint, user)
    end


    def updateOrganizationUser(org_id, user_id, properties={})
      endpoint = "/api/orgs/#{org_id}/users/#{user_id}"
      @logger.info("Updating user #{user_id} in organization #{org_id} (PATCH #{endpoint})") if @debug
      return patchRequest(endpoint, properties)
    end


    def deleteUserFromOrganization(org_id, user_id)
      endpoint = "/api/orgs/#{org_id}/users/#{user_id}"
      @logger.info("Deleting user #{user_id} in organization #{org_id} (DELETE #{endpoint})") if @debug
      return deleteRequest(endpoint)
    end

  end

end
