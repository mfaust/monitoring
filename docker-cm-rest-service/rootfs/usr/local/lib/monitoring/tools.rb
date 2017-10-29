
module Monitoring

  module Tools

    def ns_lookup(name, expire = 120 )

      # DNS
      #
      cache_key = sprintf( 'dns::%s', name )

  #     logger.debug("cache_key: #{cache_key}")

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( cache_key )

      if( dns == nil )

        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @redis.set(format('dns::%s',fqdn), { ip: ip, short: short, long: fqdn }.to_json, 320 )
          @cache.set(cache_key , expires_in: expire ) { MiniCache::Data.new( { ip: ip, short: short, long: fqdn } ) }
        else
          logger.error( 'no DNS data found!' )
          logger.error( " => #{dns}" )

          return nil, nil, nil
        end
      else

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

      end

  #     logger.debug( "redis: #{@redis.get(format('dns::%s',fqdn))}" )

      #
      # ------------------------------------------------

  #     dns    = @database.dnsData( { :ip => ip, :short => short, :fqdn => fqdn } )
  #
  #     if( dns == nil )
  #
  #       status = @database.createDNS( { :ip => ip, :short => short, :fqdn => fqdn } )
  #
  #       @cache.set( hostname , expires_in: expire ) { MiniCache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
  #     end

  #     logger.debug( sprintf( '  ip   %s ', ip ) )
  #     logger.debug( sprintf( '  host %s ', short ) )
  #     logger.debug( sprintf( '  fqdn %s ', fqdn ) )

      return ip, short, fqdn

    end


    def nodeExists?( host )

      logger.debug( "nodeExists?( #{host} )" )

      ip, short, fqdn = self.ns_lookup(host )

      d = self.nodeInformations( { :host => fqdn } )

      if( d == nil )
        return false
      end

      if( d.keys.first == fqdn )
        return true
      else
        return false
      end

  #     cache   = @cache.get( 'information' )
  #
  #     if( cache == nil )
  #       return false
  #     end
  #
  #     h = cache.dig( node.to_s )
  #
  #     if ( h == nil )
  #       return false
  #     else
  #       return true
  #     end

    end

    # check availability and create an DNS entry into our redis
    #
    def checkAvailablility?( host )

      ip, short, fqdn = self.ns_lookup(host )

      if( ip == nil && short == nil && fqdn == nil )
        return false
      end

      return {
        :ip    => ip,
        :short => short,
        :fqdn  => fqdn
      }

    end


    def messageQueue( params = {} )

      logger.debug( "messageQueue( #{params} )" )

      command = params.dig(:cmd)
      node    = params.dig(:node)
      queue   = params.dig(:queue)
      data    = params.dig(:payload)
      prio    = params.dig(:prio)  || 65536
      ttr     = params.dig(:ttr)   || 10
      delay   = params.dig(:delay) || 2

      job = {
        cmd:  command,
        node: node,
        timestamp: Time.now().strftime( '%Y-%m-%d %H:%M:%S' ),
        from: 'rest-service',
        payload: data
      }.to_json

      @mq_producer.addJob( queue, job, prio, ttr, delay )

    end

  end
end
