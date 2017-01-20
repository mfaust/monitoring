
module Icinga

  module Host

    def addHost( params = {}, host = nil, vars = {} )

      code        = nil
      result      = {}

      host = params.dig(:host) || nil
      vars = params.dig(:vars) || {}

      if( host == nil )

        return {
          :status  => 500,
          :message => 'internal Server Error'
        }
      end

      # build FQDN
      fqdn = Socket.gethostbyname( host ).first

      payload = {
        "templates" => [ "generic-host" ],
        "attrs" => {
          "address"      => fqdn,
          "display_name" => host
        }
      }

      if( ! vars.empty? )
        payload['attrs']['vars'] = vars
      end

      logger.debug( JSON.pretty_generate( payload ) )

      result = Network.put( {
        :host    => host,
        :url     => sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ),
        :headers => @headers,
        :options => @options,
        :payload => payload
      } )

      return JSON.pretty_generate( result )

    end


    def deleteHost( params = {} )

      host = params.dig(:host) || nil

      if( host == nil )

        return {
          :status  => 500,
          :message => 'internal Server Error'
        }
      end

      result = Network.delete( {
        :host    => host,
        :url     => sprintf( '%s/v1/objects/hosts/%s?cascade=1', @icingaApiUrlBase, host ),
        :headers => @headers,
        :options => @options
      } )

      return JSON.pretty_generate( result )

    end


    def listHost( params = {} )

      code        = nil
      result      = {}

      host = params.dig(:host) || nil

      result = Network.get( {
        :host => host,
        :url  => sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ),
        :headers  => @headers,
        :options  => @options
      } )

      return JSON.pretty_generate( result )

    end

  end

end
