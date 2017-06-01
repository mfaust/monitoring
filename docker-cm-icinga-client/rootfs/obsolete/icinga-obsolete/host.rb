
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

      services   = self.nodeInformation( { :host => short } )

      payload = {
        "templates" => [ "generic-host" ],
        "attrs" => {
          "address"              => fqdn,
          "display_name"         => self.nodeTag( host ),
          "max_check_attempts"   => 3,
          "check_interval"       => 60,
          "retry_interval"       => 45,
          "enable_notifications" => @icingaNotifications ? true : false
        }
      }

      # TODO: add groups
      #
      if( ! services.empty? )
        payload['attrs']['vars'] = services
      end

      if( @icingaCluster == true && @icingaSatellite != nil )
        payload['attrs']['zone'] = @icingaSatellite
      end

#       logger.debug( JSON.pretty_generate( payload ) )

      result = Network.put( {
        :host    => short,
        :url     => sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, short ),
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

      ip, short, fqdn = self.nsLookup( host )

      result = Network.delete( {
        :host    => host,
        :url     => sprintf( '%s/v1/objects/hosts/%s?cascade=1', @icingaApiUrlBase, short ),
        :headers => @headers,
        :options => @options
      } )

      return JSON.pretty_generate( result )

    end


    def listHost( params = {} )

      code        = nil
      result      = {}

      host = params.dig(:host) || nil

      if( host == nil )

        return {
          :status  => 500,
          :message => 'internal Server Error'
        }
      end

      ip, short, fqdn = self.nsLookup( host )

      result = Network.get( {
        :host    => short,
        :url     => sprintf( '%s/v1/objects/hosts/%s', @icingaApiUrlBase, short ),
        :headers => @headers,
        :options => @options
      } )

      return JSON.pretty_generate( result )

    end


    def nodeInformation( params = {} )

      logger.debug( "nodeInformation( #{params} )" )

      host             = params.dig(:host) || nil

      # in first, we need the discovered services ...
      logger.debug( sprintf( 'in first, we need information from discovery service for node \'%s\'', host ) )

      for y in 1..30

        result = @redis.discoveryData( { :short => host } )

        if( result.is_a?( Hash ) && result.count != 0 )

          services = result
          break
        else
          logger.debug( sprintf( 'waiting for data for node %s ... %d', host, y ) )
          sleep( 5 )
        end
      end

      logger.debug( "#{services}" )

      if( services != nil )

        services.each do |s|

#           logger.debug( " => service #{s}" )

          if( s.last != nil )
            s.last.reject! { |k| k == 'template' }
            s.last.reject! { |k| k == 'application' }
          end
        end

        payload = { "coremedia": services }
      else

        payload = {}
      end

      logger.debug( JSON.pretty_generate( payload ) )

      return payload

    end

  end

end
