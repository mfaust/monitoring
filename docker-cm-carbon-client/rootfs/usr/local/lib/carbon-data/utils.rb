
module CarbonData

  module Utils

    # return all known and active (online) server for monitoring
    #
    def monitoredServer()

      nodes = @database.nodes( { :status => [ Storage::MySQL::ONLINE ] } )

#       logger.debug( "database: #{nodes}" )

      return nodes

    end


    def output( data = [] )

      data.each do |d|
        if( d )
          puts d
        end
      end

    end


    def normalizeService( service )

      # normalize service names for grafana
      case service
        when 'content-management-server'
          service = 'CMS'
        when 'master-live-server'
          service = 'MLS'
        when 'replication-live-server'
          service = 'RLS'
        when 'workflow-server'
          service = 'WFS'
        when /^cae-live/
          service = 'CAE_LIVE'
        when /^cae-preview/
          service = 'CAE_PREV'
        when 'solr-master'
          service = 'SOLR_MASTER'
    #    when 'solr-slave'
    #      service = 'SOLR_SLAVE'
        when 'content-feeder'
          service = 'FEEDER_CONTENT'
        when 'caefeeder-live'
          service = 'FEEDER_LIVE'
        when 'caefeeder-preview'
          service = 'FEEDER_PREV'
      end

      return service.tr('-', '_').upcase

    end


    def timeParser( today, finalDate )

      difference = TimeDifference.between( today, finalDate ).in_each_component

      return {
        :years   => difference[:years].round,
        :months  => difference[:months].round,
        :weeks   => difference[:weeks].round,
        :days    => difference[:days].round,
        :hours   => difference[:hours].round,
        :minutes => difference[:minutes].round,
      }
    end


  end

end
