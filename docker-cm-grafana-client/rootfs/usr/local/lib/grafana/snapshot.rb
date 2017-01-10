module Grafana

  module Snapshot

    def snapshot(key)
      endpoint = "/api/snapshot/#{key}"
      @logger.info("Getting frontend settings (GET #{endpoint})") if @debug
      return getRequest(endpoint)
    end

    def create_snapshot(dashboard={})
      endpoint = "/api/snapshot"
      @logger.info("Creating dashboard snapshot (POST #{endpoint})") if @debug
      return postRequest(endpoint, dashboard)
    end

    def delete_snapshot(key)
      endpoint = "/api/snapshots-delete/#{key}"
      @logger.info("Deleting snapshot ID #{key} (GET #{endpoint})") if @debug
      return deleteRequest(endpoint)
    end

  end

end
