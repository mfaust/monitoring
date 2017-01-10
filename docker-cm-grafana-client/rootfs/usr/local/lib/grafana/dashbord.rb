
module Grafana

  module Dashboard

    def createSlug(text)
      if text =~ /\s/
        if text =~ /-/
          text = text.gsub(/\s+/, "").downcase
        else
          text = text.gsub(/\s+/, "-").downcase
        end
      end
      return text
    end

    def dashboard( name = '' )
      name = self.createSlug( name )
      endpoint = "/api/dashboards/db/#{name}"

      loggerinfo("Attempting to get dashboard (GET /api/dashboards/db/#{name})")
      return getRequest(endpoint)
    end

    def createDashboard( properties = {} )
      endpoint = "/api/dashboards/db"
      dashboard = self.build_template(properties)
      loggerinfo("Creating dashboard: #{properties['title']} (POST /api/dashboards/db)")
      return postRequest(endpoint, dashboard)
    end

    def deleteDashboard( name )
      name = self.createSlug( name )
      endpoint = "/api/dashboards/db/#{name}"
      loggerinfo("Deleting dahsboard ID #{id} (DELETE #{endpoint})")
      return deleteRequest(endpoint)
    end

    def homeDashboard()
      endpoint = "/api/dashboards/home"
      loggerinfo("Attempting to get home dashboard (GET #{endpoint})")
      return getRequest(endpoint)
    end

    def dashboardTags()
      endpoint = "/api/dashboards/tags"
      loggerinfo("Attempting to get dashboard tags(GET #{endpoint})")
      return getRequest(endpoint)
    end

    def searchDashboards( params = {} )
      params['query'] = (params['query'].length >= 1 ? CGI::escape(params['query']) : '' )
      params['starred'] = (params['starred'] ? 'true' : 'false')

      endpoint = "/api/search/?query=#{params['query']}&starred=#{params['starred']}&tag=#{params['tags']}"
      loggerinfo("Attempting to search for dashboards (GET #{endpoint})")
      return getRequest(endpoint)
    end

  end

end
