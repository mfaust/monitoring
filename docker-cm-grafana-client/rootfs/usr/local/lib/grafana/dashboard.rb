
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

      logger.debug( "Attempting to get dashboard (GET /api/dashboards/db/#{name})" )

      return getRequest( endpoint )
    end

    def createDashboard( properties = {} )

      endpoint = "/api/dashboards/db"
      dashboard = self.buildTemplate( properties )

      logger.debug("Creating dashboard: #{properties['title']} (POST /api/dashboards/db)")

      return postRequest( endpoint, dashboard )
    end

    def deleteDashboard( name )

      name = self.createSlug( name )
      endpoint = "/api/dashboards/db/#{name}"

      logger.debug("Deleting dahsboard ID #{id} (DELETE #{endpoint})")

      return deleteRequest(endpoint)
    end

    def homeDashboard()

      endpoint = "/api/dashboards/home"

      logger.debug("Attempting to get home dashboard (GET #{endpoint})")

      return getRequest(endpoint)
    end

    def dashboardTags()

      endpoint = "/api/dashboards/tags"

      logger.debug("Attempting to get dashboard tags(GET #{endpoint})")

      return getRequest(endpoint)
    end



    #    searchDashboards( { :tags   => host } )
    #    searchDashboards( { :tags   => [ host, 'tag1' ] } )
    #    searchDashboards( { :tags   => [ 'tag2' ] } )
    #    searchDashboards( { :query  => title } )
    #    searchDashboards( { :starred => true } )

    def searchDashboards( params = {} )

      query   = params[:query]     ? params[:query]   : nil
      starred = params[:starred]   ? params[:starred] : nil
      tags    = params[:tags]      ? params[:tags]    : nil
      api     = Array.new()

      if( query != nil )
        api << sprintf( 'query=%s', CGI::escape( query ) )
      end

      if( starred != nil )
        api << sprintf( 'starred=%s', starred ? 'true' : 'false' )
      end

      if( tags != nil )

        if( tags.is_a?( Array ) )
          tags = tags.join( '&tag=' )
        end

        api << sprintf( 'tag=%s', tags )
      end

      api = api.join( '&' )

      endpoint = sprintf( '/api/search/?%s' , api )

      logger.debug("Attempting to search for dashboards (GET #{endpoint})")

      return getRequest(endpoint)
    end


  end

end
