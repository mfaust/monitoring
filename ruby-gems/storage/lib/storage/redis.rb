#
#
#

require 'redis'

# ---------------------------------------------------------------------------------------

module Storage

  class RedisClient

#     include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      @host   = params.dig(:redis, :host)
      @port   = params.dig(:redis, :port)     || 6379
      @db     = params.dig(:redis, :database) || 1

      self.prepare
    end


    def self.logger
      @@logger ||= Logger.new(STDOUT)
    end


    def self.logger=(logger)
      @@logger = logger
    end



    def prepare

      @redis = nil

      begin
        if( @redis.nil? )

#          logger.debug( 'try ...' )

          @redis = Redis.new(
            :host            => @host,
            :port            => @port,
            :db              => @db,
            :connect_timeout => 1.0,
            :read_timeout    => 1.0,
            :write_timeout   => 0.5
          )
        end
      rescue => e
        puts e
#         logger.error( e )
      end


    end


    def check_database

      if( @redis.nil? )
        self.prepare

        if( @redis.nil? )
          return false
        end
      end

    end


    def self.cache_key( params = {} )

      params   = Hash[params.sort]
      checksum = Digest::MD5.hexdigest( params.to_s )

      return checksum

    end


    def get( key )

      data =  @redis.get( key )

      if( data.nil? )
        return nil
      elsif( data == 'true' )
        return true
      elsif( data == 'false' )
        return false
      elsif( data.is_a?( String ) && data == '' )
        return nil
      else

        begin
          data = eval( data )
        rescue => e
          puts e
#           logger.error( e )
        end

#         data = JSON.parse( data, :quirks_mode => true )
      end

      data.deep_string_keys

    end


    def set( key, value, expire = nil )

      @redis.setex( key, expire, value ) unless( expire.nil? )

      @redis.set( key, value )
    end


    def delete( key )

      @redis.delete( key )
    end


    # -- dns ------------------------------------
    #
    def create_dns(params = {} )

#       logger.debug( "create_dns( #{params} )" )
#       logger.debug( caller )

      return false if( self.check_database == false )

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      long    = params.dig(:long)

      cachekey = Storage::RedisClient.cache_key({ short: short } )

      dns = @redis.get( format( '%s-dns', cachekey ) )

      if( dns.nil? )

        to_store = { ip: ip, shortname: short, longname: long, created: DateTime.now }.to_json

        @redis.set(format( '%s-dns', cachekey ), to_store )
      else

        warn 'DNS Entry already created:'
        warn dns
#         logger.warn( 'DNS Entry already created:' )
#         logger.warn( dns )
      end

#       self.setStatus( { :short => short, :status => Storage::RedisClient::PREPARE } )

      self.add_node({ short: short, key: cachekey } )

#       self.setStatus( { :short => short, :status => Storage::RedisClient::ONLINE } )

    end


    def remove_dns(params = {} )

      return false if( self.check_database == false )

      short   = params.dig(:short)

      cachekey = Storage::RedisClient.cache_key({ short: short } )

      self.set_status({ short: short, status: Storage::RedisClient::DELETE } )

      keys = [
        format( '%s-measurements', cachekey ),
        format( '%s-discovery'   , cachekey ),
        format( '%s-status'      , cachekey ),
        format( '%s-config'      , cachekey ),
        format( '%s-dns'         , cachekey ),
        cachekey
      ]

      status = @redis.del( *keys )

#       logger.debug( status )

#       @redis.del( format( '%s-measurements', cachekey ) )
#       @redis.del( format( '%s-discovery'   , cachekey ) )
#       @redis.del( format( '%s-status'      , cachekey ) )
#       @redis.del( format( '%s-dns'         , cachekey ) )
#       @redis.del( cachekey )


      status = self.remove_node({ short: short, key: cachekey } )

#       logger.debug( status )

      true

    end


    def dns_data(params = {} )

      return false if( self.check_database == false )

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      long    = params.dig(:long)

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key({ short: short } )
      )

      result = @redis.get( cachekey )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      { ip: result.dig('ip'), shortname: result.dig('shortname'), longname: result.dig('longname') }
    end
    #
    # -- dns ------------------------------------



    # -- configurations -------------------------
    #

    def create_config(params = {}, append = false )

#       logger.debug( "createConfig( #{params}, #{append} )" )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      if( append == true )

        existing_data = @redis.get( cachekey )

        unless( existing_data.nil? )

          existing_data = JSON.parse( existing_data ) if( existing_data.is_a?( String ) )

          data_org = existing_data.dig('data')

          # transform a Array to Hash
          data_org = Hash[*data_org] if( data_org.is_a?( Array ) )

          data = data_org.merge( data )

          # transform hash keys to symbols
          data = data.deep_string_keys
        end
      end

      to_store = { ip: dns_ip, shortname: dns_shortname, data: data, created: DateTime.now }.to_json

#       logger.debug( to_store )

      result = @redis.set( cachekey, to_store )

#       logger.debug( result )

    end


    def remove_config(params = {} )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      key          = params.dig(:key)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      # delete single config
      if (key.nil?)
        # remove all data
        @redis.del(cachekey)
      else

        existing_data = @redis.get(cachekey)
        existing_data = JSON.parse(existing_data) if (existing_data.is_a?(String))
        data = existing_data.dig('data').tap { |hs| hs.delete(key) }
        existing_data['data'] = data

        self.create_config({ short: dns_shortname, data: existing_data })
      end

    end


    def config( params = {} )

#       logger.debug( "config( #{params} )" )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      key          = params.dig(:key)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      result = @redis.get( cachekey )

      return { short: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      if (key.nil?)
        result = result.dig('data').deep_string_keys
      else result = { key.to_s => result.dig('data', key.to_s) }
      end

      result
    end
    #
    # -- configurations -------------------------


    # -- discovery ------------------------------
    #
    def create_discovery(params = {}, append = false )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = format(
        '%s-discovery',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      if( append == true )

        existing_data = @redis.get( cachekey )

        unless( existing_data.nil? )

          existing_data = JSON.parse( existing_data ) if( existing_data.is_a?( String ) )

          data_org = existing_data.dig('data')

          # transform a Array to Hash
          data_org = Hash[*data_org] if( data_org.is_a?( Array ) )

          data = data_org.merge( data )

          # transform hash keys to symbols
          data = data.deep_string_keys
        end

      end

      to_store = { short: dns_shortname, data: data, created: DateTime.now }.to_json

      @redis.set( cachekey, to_store )

    end


    def discovery_data(params = {} )

      return false if( self.check_database == false )

      short   = params.dig(:short)
      service = params.dig(:service)

      cachekey = format(
        '%s-discovery',
        Storage::RedisClient.cache_key({ short: short } )
      )

      result = @redis.get( cachekey )

#       logger.debug( result )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      if (service.nil?)
        result = result.dig('data')
      else result = { service.to_sym => result.dig('data', service) }
      end

      result.deep_string_keys
    end
    #
    # -- discovery ------------------------------


    # -- measurements ---------------------------
    #
    def create_measurements(params = {} )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = format(
        '%s-measurements',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      to_store = { short: dns_shortname, data: data, created: DateTime.now }.to_json

      @redis.set( cachekey, to_store )

    end


    def measurements( params = {} )

      return false if( self.check_database == false )

      dns_ip        = params.dig(:ip)
      dns_shortname = params.dig(:short)
      application  = params.dig(:application)

      cachekey = format(
        '%s-measurements',
        Storage::RedisClient.cache_key({ short: dns_shortname } )
      )

      result = @redis.get( cachekey )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      if (application.nil?)
        result = result.dig('data')
      else result = { application => result.dig('data', application) }
      end

      result
    end
    #
    # -- measurements ---------------------------


    # -- nodes ----------------------------------
    #
    def add_node(params = {} )

      return false if( self.check_database == false )

      short  = params.dig(:short)
      key    = params.dig(:key)

      cachekey = 'nodes'

      existing_data = @redis.get( cachekey )

      if (existing_data.nil?)
        data = { key.to_s => short }
      else

        existing_data = JSON.parse(existing_data) if (existing_data.is_a?(String))

        data_org = existing_data.dig('data')

        if (data_org.nil?)
          data = { key.to_s => short }
        else # transform a Array to Hash
          data_org = Hash[*data_org] if (data_org.is_a?(Array))

          founded_keys = data_org.keys

          # node already save -> GO OUT
          return if (founded_keys.include?(key.to_s) == true)

          data = data_org.merge({ key.to_s => short })
        end

      end

      # transform hash keys to symbols
      data = data.deep_string_keys

      to_store = { data: data }.to_json

      @redis.set( cachekey, to_store )

    end


    def remove_node(params = {} )

      return false if( self.check_database == false )

      short  = params.dig(:short)

      cachekey = 'nodes'

      existing_data = @redis.get( cachekey )
      existing_data = JSON.parse( existing_data ) if( existing_data.is_a?( String ) )
      data = existing_data.dig('data')
      data = data.tap { |hs,d| hs.delete(  Storage::RedisClient.cache_key({ short: short } ) ) }

      # transform hash keys to symbols
#       data = data.deep_string_keys

      to_store = { data: data }.to_json

#       logger.debug( to_store )

      @redis.set( cachekey, to_store )

    end


    def nodes( params = {} )

      return false if( self.check_database == false )

      short     = params.dig(:short)
      status    = params.dig(:status)  # Database::ONLINE

      status = status ? 0 : 1 if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )

      cachekey  = 'nodes'

      result    = @redis.get( cachekey )

      return false if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      unless( short.nil? )

        result   = result.dig('data').values.select { |x| x == short }

        return result.first.to_s

      end

      unless( status.nil? )

        keys   = result.dig('data')

        if( keys.nil? )
          return false
        else
          keys = keys.values
        end

        result = Hash.new

        keys.each do |k|

          d = self.status( { short: k } ).deep_string_keys

          node_status = d.dig('status') || 0


          node_status = node_status ? 0 : 1 if( node_status.is_a?( TrueClass ) || node_status.is_a?( FalseClass ) )

          if( node_status.to_i == status.to_i )

            dns_data    = self.dns_data({ short: k } )
#             statusData = self.status( { :short => k } )

#             logger.debug( statusData )

            result[k.to_s] ||= {}
            result[k.to_s] = dns_data

          end
        end

        result
      end

      #
      #
      result.dig('data').values

    end
    #
    # -- nodes ----------------------------------

    # -- status ---------------------------------
    #
    def set_status( params = {} )

#       logger.debug( "setStatus( #{params} )" )
#       logger.debug( caller )

      return false if( self.check_database == false )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      status  = params.dig(:status) || 0

      status = status ? 0 : 1 if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )

      return { status: 404, message: 'missing short hostname' }  if( name.nil? )

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key({ short: name } )
      )

      result = @redis.get( cachekey )

      return { short: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      result['status'] = status
      result = result.to_json

      @redis.set( cachekey, result )
    end


    def status( params = {} )

#       logger.debug( "status( #{params} )" )

      return false if( self.check_database == false )

      short   = params.dig(:short)
      status  = params.dig(:status) || 0

      return { status: 404, message: 'missing short hostname' } if( short.nil? )

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key({ short: short } )
      )

      result = @redis.get( cachekey )


      return { status: 0, created: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

#       logger.debug( result )

      status   = result.dig( 'status' ) || 0
      created  = result.dig( 'created' )

      status = status ? 0 : 1 if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )

      message = case status
        when Storage::RedisClient::OFFLINE
          'offline'
        when Storage::RedisClient::ONLINE
          'online'
        when Storage::RedisClient::DELETE
          'delete'
        when Storage::RedisClient::PREPARE
          'prepare'
        else
          'unknown'
        end

#       case status
#       when 0, false
#         status = 'offline'
#       when 1, true
#         status = 'online'
#       when 98
#         status = 'delete'
#       when 99
#         status = 'prepare'
#       else
#         status = 'unknown'
#       end


      { short: short, status: status, message: message, created: created }
    end
    #
    # -- status ---------------------------------

#     def parsedResponse( r )
#
#       return JSON.parse( r )
#     rescue JSON::ParserError => e
#       return r # do smth
#
#     end

  end

end

# ---------------------------------------------------------------------------------------

# EOF

