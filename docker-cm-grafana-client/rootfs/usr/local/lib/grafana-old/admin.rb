
module Grafana

  module Admin


    def adminSettings()
      endpoint = "/api/admin/settings"
      logger.info("Getting admin settings (GET #{endpoint})")
      return getRequest(endpoint)
    end


    def updateUserPermissions(id, perm)

      valid_perms = ['Viewer','Editor','Read Only Editor','Admin']

      if( perm.is_a?( String ) && !valid_perms.include?(perm) )
        logger.warn("Basic user permissions include: #{valid_perms.join(',')}")
        return false
      elsif( perm.is_a?( Hash ) &&
        ( !perm.has_key?('isGrafanaAdmin') || ![true,false].include?(perm['isGrafanaAdmin']) ) )

        logger.warn("Grafana admin permission must be either true or false")
        
        return false
      end

      logger.info("Updating user ID #{id} permissions")

      if( perm.is_a?( Hash ) )

        endpoint = "/api/admin/users/#{id}/permissions"
        logger.info("Updating user ID #{id} permissions (PUT #{endpoint})")

        return putRequest(endpoint, {"isGrafanaAdmin" => perm['isGrafanaAdmin']}.to_json)
      else
        org = self.current_org()
        endpoint = "/api/orgs/#{org['id']}/users/#{id}"
        logger.info("Updating user ID #{id} permissions (PUT #{endpoint})")
        user = {
          'name' => org['name'],
          'orgId' => org['id'],
          'role' => perm.downcase.capitalize
        }
        return patchRequest(endpoint, user.to_json)
      end
    end


    def deleteUser(user_id)
      if user_id == 1
        logger.warn("Can't delete user ID #{user_id} (admin user)")
        return false
      end
      endpoint = "/api/admin/users/#{user_id}"
      logger.info("Deleting user ID #{user_id} (DELETE #{endpoint})")
      return deleteRequest(endpoint)
    end


    def createUser(properties={})
      endpoint = "/api/admin/users"
      logger.info("Creating user: #{properties['name']}")
      logger.info("Data: #{properties.to_s}")
      return postRequest(endpoint, properties.to_json)
    end


    def updateUserPass(user_id,password)

      endpoint = " /api/admin/users/#{user_id}/#{password}"
      logger.info("Updating password for user ID #{user_id} (PUT #{endpoint})")
      return putRequest(endpoint,properties)
    end


  end

end
