
require 'json'

module Grafana

  module Dashboard

    def create_slug(text)
      if text =~ /\s/
        if text =~ /-/
          text = text.gsub(/\s+/, "").downcase
        else
          text = text.gsub(/\s+/, "-").downcase
        end
      end
      return text
    end

    def get_dashboard(name='')
      name = self.create_slug(name)
      endpoint = "/api/dashboards/db/#{name}"
      @log.debug("Attempting to get dashboard (GET /api/dashboards/db/#{name})")

      return get_request(endpoint)
    end

    def create_dashboard( properties = {} )

      endpoint = "/api/dashboards/db"
      dashboard = self.build_template(properties)
      @log.debug("Creating dashboard: #{properties['title']} (POST /api/dashboards/db)")

      @log.debug( JSON.pretty_generate( JSON.parse(dashboard ) ) )
      return post_request(endpoint, dashboard)
    end

    def delete_dashboard(name)
      name = self.create_slug(name)
      data = self.get_dashboard( name )

      if( ! data.to_s == '' )
        id = data['dashboard']['id'] ? data['dashboard']['id'] : nil

        if( id != nil )
          endpoint = "/api/dashboards/db/#{name}"
          @log.debug("Deleting dahsboard ID #{id} (DELETE #{endpoint})")
          return delete_request( endpoint )
        else
          @log.error( 'no id for dashboard found' )
          return false
        end
      else
        @log.error( 'no dashboard found' )
      end
    end

    def get_home_dashboard()
      endpoint = "/api/dashboards/home"
      @log.debug("Attempting to get home dashboard (GET #{endpoint})")
      return get_request(endpoint)
    end

    def get_dashboard_tags()
      endpoint = "/api/dashboards/tags"
      @log.debug("Attempting to get dashboard tags(GET #{endpoint})")
      return get_request(endpoint)
    end

    def search_dashboards(params={})
      params['query'] = (params['query'].length >= 1 ? CGI::escape(params['query']) : '' )
      params['starred'] = (params['starred'] ? 'true' : 'false')
      endpoint = "/api/search/?query=#{params['query']}&starred=#{params['starred']}&tag=#{params['tags']}"
      @log.debug("Attempting to search for dashboards (GET #{endpoint})")
      return get_request(endpoint)
    end

  end

end
