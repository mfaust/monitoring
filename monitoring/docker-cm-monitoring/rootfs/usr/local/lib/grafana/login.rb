module Grafana

  module Login

    def ping_session()
      endpoint = "/api/login/ping"
      @log.debug("Pingning current session (GET #{endpoint})")
      return get_request(endpoint)

    end
  end

end
