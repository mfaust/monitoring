
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
        when 'content-feeder'
          service = 'FEEDER_CONTENT'
        when 'caefeeder-live'
          service = 'FEEDER_LIVE'
        when 'caefeeder-preview'
          service = 'FEEDER_PREV'
        when 'node-exporter'
          service = 'NODE_EXPORTER'
        when 'http-status'
          service = 'HTTP_STATUS'
      end

      return service.tr('-', '_').upcase

    end

    def timeParser( start_time, end_time )

#      logger.debug( "timeParser( #{start_time}, #{end_time} )" )

      seconds_diff = (start_time - end_time).to_i.abs

      {
        years: (seconds_diff / 31556952),
        months: (seconds_diff / 2628288),
        weeks: (seconds_diff / 604800),
        days: (seconds_diff / 86400),
        hours: (seconds_diff / 3600),
        minutes: (seconds_diff / 60),
        seconds: seconds_diff,
      }
    end


    def timeParserOBSOLETE( today, final )

      logger.debug( "timeParser( #{today}, #{final} )" )

      difference = TimeDifference.between( today, final ).in_each_component

      logger.debug(difference)

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
