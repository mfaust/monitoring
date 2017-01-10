module Grafana

  module Login

    def ping_session()
      endpoint = "/api/login/ping"
      @logger.info("Pingning current session (GET #{endpoint})") if @debug
      return getRequest(endpoint)

    end
  end

end
