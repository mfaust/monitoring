
module Grafana

  module Login

    def ping_session()

      endpoint = "/api/login/ping"

      @logger.info( "Pinging current session (GET #{endpoint})" )

      result = self.getRequest( endpoint )

      return result

    end
  end

end
