
module Grafana

  module Datasource

    # Getting data source namespaces (POST /api/datasources/proxy/#{datasource_id})
#     def namespaces(datasource_id)
#
#       endpoint = "/api/datasources/proxy/#{datasource_id}"
#       return postRequest( endpoint, { "action" => "__GetNamespaces" }.to_json )
#     end


    def dataSources()

      endpoint = "/api/datasources"
      logger.info("Attempting to get existing data sources (GET #{endpoint})")

      data_sources = getRequest( endpoint )

      if( !data_sources )
        return false
      end

      data_source_map = {}
      data_sources.each { |ds|
        data_source_map[ds['id']] = ds
      }

      return data_source_map
    end


    def dataSource(id)
      endpoint = "/api/datasources/#{id}"
      logger.info("Attempting to get existing data source ID #{id}")
      return getRequest(endpoint)
    end


    def updateDataSource( id, ds = {} )
      existing_ds = self.dataSource(id)
      ds = existing_ds.merge(ds)
      endpoint = "/api/datasources/#{id}"
      logger.info("Updating data source ID #{id}")
      return putRequest(endpoint, ds.to_json)
    end


    def createDataSource( ds = {} )
      if ds == {} || !ds.has_key?('name') || !ds.has_key?('database')
        logger.error("Error: missing 'name' and 'database' values!")
        return false
      end
      endpoint = "/api/datasources"
      logger.info("Creating data source: #{ds['name']} (database: #{ds['database']})")
      return postRequest(endpoint, ds.to_json)
    end


    def deleteDataSource(id)
      endpoint = "/api/datasources/#{id}"
      logger.info("Deleting data source #{id} (DELETE #{endpoint})")
      return deleteRequest(endpoint)
    end


    def availableDataSourceTypes()
      endpoint = '/api/datasources'
      logger.info("Attempting to get existing data source types (GET #{endpoint})")
      return getRequest(endpoint)
    end

  end

end
