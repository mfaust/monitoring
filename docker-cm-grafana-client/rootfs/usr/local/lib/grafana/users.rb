
module Grafana

  module Users


    def allUsers()
      endpoint = "/api/users"
      @logger.info("Getting all users (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end


    def userById(id)
      endpoint = "/api/users/#{id}"
      @logger.info("Getting user ID #{id} (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def searchForUsersBy( search = {} )
      all_users = self.all_users()
      key, value = search.first
      @logger.info("Searching for users matching #{key} = #{value}") if @debug
      users = []
      all_users.each do |u|
        if u[key] && u[key] == value
          users.push(u)
        end
      end
      return (users.length >= 1 ? users : false)
    end


    def updateUserInfo(id, properties={})
      endpoint = "/api/users/#{id}"
      @logger.info("Updating user ID #{id}") if @debug
      existing_user = self.user(id)
      if !existing_user
        @logger.error("User #{id} does not exist") if @debug
        return false
      end
      properties = existing_user.merge(properties)
      return putRequest(endpoint,properties.to_json)
    end

    
    def userOrganizations(userid)

      endpoint = "/api/users/#{userid}/orgs"
      @logger.info("Getting organizations for user #{id} (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

  end

end
