
module Icinga

  module Application

    def applicationData()

      apiUrl     = sprintf( '%s/v1/status/IcingaApplication', @icingaApiUrlBase )
      restClient = RestClient::Resource.new( URI.encode( apiUrl ), @options )
      data       = JSON.parse( restClient.get( @headers ).body )
      result     = data['results'][0]['status'] # there's only one row

      return result

    end

  end
end
