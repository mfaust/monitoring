
module Icinga

  module Host

    def addHost( params = {} )

      logger.debug( "addHost( #{params} )" )

      code        = nil
      result      = {}

      host     = params.dig(:host) || nil
      vars     = params.dig(:vars) || {}
      endpoint = nil

      if( host == nil )

        return {
          :status  => 500,
          :message => 'internal Server Error'
        }
      end

      start = Time.now

      # get a DNS record
      #
      ip, short, fqdn = self.nsLookup( host )

      # add hostname to an blocking cache
      #
      if( @jobs.jobs( { :ip => ip, :short => short, :fqdn => fqdn } ) == true )

        logger.warn( 'we are working on this job' )

        return {
          :status  => 409, # 409 Conflict
          :message => 'we are working on this job'
        }
      end

      @jobs.add( { :ip => ip, :short => short, :fqdn => fqdn } )

      services   = self.nodeInformation( { :host => host } )

      payload = {
        "templates" => [ "generic-host" ],
        "attrs" => {
          "address"              => fqdn,
          "display_name"         => host,
          "max_check_attempts"   => 3,
          "check_interval"       => 60,
          "retry_interval"       => 45,
          "enable_notifications" => @icingaNotifications
        }
      }

      if( ! services.empty? )
        payload['attrs']['vars'] = services
      end

      if( @icingaCluster == true && @icingaSatellite != nil )
        payload['attrs']['zone'] = @icingaSatellite
      end

#       logger.debug( JSON.pretty_generate( payload ) )

      result = Network.put( {
        :host    => host,
        :url     => sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, host ),
        :headers => @headers,
        :options => @options,
        :payload => payload
      } )

      @jobs.del( { :ip => ip, :short => short, :fqdn => fqdn } )

      finish = Time.now
      logger.info( sprintf( 'finished in %s seconds', finish - start ) )

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


    def nodeInformation( params = {} )

      logger.debug( "nodeInformation( #{params} )" )

      host             = params.dig(:host) || nil

      discoveryStatus  = nil
      discoveryPayload = nil

      # in first, we need the discovered services ...
      logger.debug( 'in first, we need information from discovery service' )
      logger.debug( 'send message to \'mq-discover\'' )

      self.sendMessage( { :cmd => 'info', :node => host, :queue => 'mq-discover', :payload => {}, :prio => 2, :ttr => 1, :delay => 8 } )

      for y in 1..30

        result      = @mqConsumer.getJobFromTube('mq-discover-info')

        logger.debug( result.class.to_s )
        logger.debug( result )

        if( result.is_a?( Hash ) && result.count != 0 && result.dig( :body, 'payload', 'services' ) != nil )

          discoveryStatus = result
          break
        else
          logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-discover-info', y ) )
          sleep( 5 )
        end
      end

      if( discoveryStatus == nil )
        logger.warn( 'we hab no discovery datas' )
        logger.debug( discoveryStatus )

        return {}
      end

      discoveryPayload = discoveryStatus.dig( :body, 'payload' )
      services         = discoveryStatus.dig( :body, 'payload', 'services' )

      discoveryPayload.reject! { |k| k == 'status' }
      discoveryPayload.reject! { |k| k == 'mode' }

      if( services != nil )

        services.each do |s|

#           logger.debug( " => service #{s}" )

          if( s.last != nil )
            s.last.reject! { |k| k == 'template' }
            s.last.reject! { |k| k == 'application' }
          end
        end

        if( discoveryPayload.is_a?( Hash ) )
          discoveryPayload = discoveryPayload.to_json
        end

        payload = JSON.parse( discoveryPayload.split('"services":').join('"coremedia":') )
      else

        payload = {}
      end

      return payload

    end

  end

end
