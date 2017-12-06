
module Monitoring

  module Tools

    def ns_lookup( name, expire = 120 )

      logger.debug( "ns_lookup( #{name}, #{expire} )" )

      # DNS
      #
      cache_key = format( 'dns::%s', name )

      dns      = @cache.get( cache_key )

      if( dns.nil? )

        logger.debug( 'no cached DNS data' )

        dns = @database.dns_data( short: name, fqdn: name )

        unless( dns.nil? )

          logger.debug( 'use database entries' )

          ip    = dns.dig('ip')
          short = dns.dig('name')
          fqdn  = dns.dig('fqdn')

          @cache.set( cache_key , expires_in: expire ) { MiniCache::Data.new( ip: ip, short: short, long: fqdn ) }

          return ip, short, fqdn
        end

        logger.debug( format( 'resolve dns name %s', name ) )

        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:fqdn)

        if( ip.nil? && short.nil? && fqdn.nil? )
          logger.error( 'no DNS data found!' )
          logger.error( " => #{dns}" )

          ip       = nil
          short    = nil
          fqdn     = nil
        else
          @redis.set(format('dns::%s',fqdn), { ip: ip, short: short, long: fqdn }.to_json, 320 )
          @cache.set(cache_key , expires_in: expire ) { MiniCache::Data.new( { ip: ip, short: short, long: fqdn } ) }
        end
      else
        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:fqdn)
      end

      return ip, short, fqdn
    end


    def host_exists?( host )

      logger.debug( "host_exists?( #{host} )" )

      ip, short, fqdn = ns_lookup(host)

      d = host_informations( host: fqdn )

      return false if( d.nil? )

      return true if( d.keys.first == fqdn )

      return false
    end

    # check availability and create an DNS entry into our redis
    #
    def host_avail?( host )

      ip, short, fqdn = ns_lookup(host )

      return false if( ip == nil && short == nil && fqdn == nil )

      { ip: ip, short: short, fqdn: fqdn }
    end


    def message_queue( params = {} )

      logger.debug( "message_queue( #{params} )" )

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

      @mq_producer.add_job( queue, job, prio, ttr, delay )

    end

  end
end
