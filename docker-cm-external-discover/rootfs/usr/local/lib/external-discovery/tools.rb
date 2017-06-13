
module ExternalDiscovery

  module Tools

    def nsLookup( name, expire = 120 )

      # DNS
      #
      hostname = sprintf( 'dns-%s', name )

      ip       = nil
      short    = nil
      fqdn     = nil

      dns      = @cache.get( hostname )

      if( dns == nil )

#         logger.debug( 'create cached DNS data' )
        # create DNS Information
        dns      = Utils::Network.resolv( name )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

        if( ip != nil && short != nil && fqdn != nil )

          @cache.set( hostname , expiresIn: expire ) { Cache::Data.new( { 'ip': ip, 'short': short, 'long': fqdn } ) }
        else
          logger.error( 'no DNS data found!' )
          logger.error( " => #{dns}" )
        end
      else

#         logger.debug( 're-use cached DNS data' )

        ip    = dns.dig(:ip)
        short = dns.dig(:short)
        fqdn  = dns.dig(:long)

      end
      #
      # ------------------------------------------------

#       logger.debug( sprintf( ' ip   %s ', ip ) )
#       logger.debug( sprintf( ' host %s ', short ) )
#       logger.debug( sprintf( ' fqdn %s ', fqdn ) )

      return ip, short, fqdn

    end


    def getFqdn( data )

      b = Array.new
      data.each do |x|
        b <<  x.select { |key, value| key.to_s.match(/^dns/) }.values.first.dig('fqdn')
      end
      b
    end


    def entry_with_fqdn( data, fqdn )

      data.find{ |x| x.dig('dns','fqdn') == fqdn }
    end


    def findUid( historic, uid )

      logger.debug( sprintf( 'findUid %s', uid ) )

      if( historic.is_a?(Array) && historic.count() > 0 )

        f = {}

        historic.each do |h|

          f = h.select { |key, value| key.to_s.match(/^id/) }

          if( f[:id].to_s == uid )
            f = h
            break
          else
            f = {}
          end
        end

        return f

      else
        return nil
      end

    end



    def normalizeName( n, filter = [] )

      filter.each do |f|
        n.gsub!( f, '' )
      end

      n.gsub!('development-','dev ')
      n.gsub!('production-' ,'prod ')
      n.gsub!('caepreview'  ,'cae preview')
      n.gsub!('management-' ,'be ')
      n.gsub!('delivery-'   ,'fe ')
      n.gsub!( '-',' ' )

      return n

    end


    def graphiteIdentifier( params = {} )

      name      = params.dig(:name)

      name.gsub!('development-','dev-')
      name.gsub!('production-' ,'prod-')
      name.gsub!('storage-'    , '')
      name.gsub!('management-' ,'be-')
      name.gsub!('delivery-'   ,'fe-')
      name.gsub!(' ', '-')

      return name

    end


    def extractInstanceInformation( data = {} )

#       logger.debug( "extractInstanceInformation( #{data} )" )

#       {
#         "fqdn": "i-0130817e34d231f1d.monitoring",
#         "name": "i-0130817e34d231f1d",
#         "state": "running",
#         "uid": "i-0130817e34d231f1d",
#         "launch_time": "2017-05-16 05:32:41 UTC",
#         "dns": {
#           "ip": "172.31.11.111",
#           "short": "ip-172-31-11-111",
#           "name": "ip-172-31-11-111.ec2.internal"
#         },
#         "tags": {
#           "cname": "management-solr.development.cosmos.internal.",
#           "customer": "cosmos",
#           "environment": "development",
#           "name": "cosmos-development-storage-management-solr",
#           "tier": "storage"
#         },
#         "checksum": "c17e8c86ffeea56ae72049212d8e153a"
#       }

      fqdn        = data.dig('fqdn')
#       name        = data.dig('name')
      uuid        = data.dig('uid')
      state       = data.dig('state') || 'running'
      tags        = data.dig('tags')  || []
      cname       = data.dig('tags', 'cname')
      name        = data.dig('tags', 'name')
      tier        = data.dig('tags', 'tier')
      customer    = data.dig('tags', 'customer')
      environment = data.dig('tags', 'environment')
      dns_ip      = data.dig('dns' , 'ip')
      dns_short   = data.dig('dns' , 'short')
      dns_fqdn    = data.dig('dns' , 'fqdn')

      return uuid, dns_ip, dns_short, dns_fqdn, fqdn, name, state, tags, cname, name, tier, customer, environment

    end



  end

end

# ---------------------------------------------------------------------------------------
# EOF
