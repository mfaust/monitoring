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

    def initialize( params )

      @host   = params.dig(:redis, :host)
      @port   = params.dig(:redis, :port)     || 6379
      @db     = params.dig(:redis, :database) || 1
      @redis  = nil

      self.prepare
    end


    def self.logger
      @@logger ||= Logger.new(STDOUT)
    end


    def self.logger=(logger)
      @@logger = logger
    end


    def prepare
      begin
        if( @redis.nil? )
          @redis = Redis.new(
            host: @host,
            port: @port,
            db: @db,
            connect_timeout: 1.0,
            read_timeout: 1.0,
            write_timeout: 0.5
          )
        end
      rescue => e
        puts e
      end
    end


    def check_database

      if( @redis.nil? )
        self.prepare
        return false if( @redis.nil? )
      end

      true
    end


    def self.cache_key( params = {} )
      Digest::MD5.hexdigest( Hash[params.sort].to_s )
    end


    def get( key )

      data =  @redis.get( key )

      return nil if( data.nil? )
      return true if( data == 'true' )
      return false if( data == 'false' )
      return nil if( data.is_a?( String ) && data == '' )

        begin
          data = eval( data )
        rescue => e
          puts e
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
    def create_dns(params)

      return false if( check_database == false )

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      cachekey = Storage::RedisClient.cache_key( fqdn: fqdn )

      dns = @redis.get( format( '%s-dns', cachekey ) )

      if( dns.nil? )
        to_store = { ip: ip, short: short, fqdn: fqdn, created: DateTime.now }.to_json
        @redis.set(format( '%s-dns', cachekey ), to_store )
      else
        warn 'DNS Entry already created:'
        warn dns
      end

      self.add_node( fqdn: fqdn, key: cachekey )
    end


    def remove_dns(params)

      return false if( check_database == false )

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      cachekey = Storage::RedisClient.cache_key(fqdn: fqdn)

      set_status( ip: ip, short: name, fqdn: fqdn, status: Storage::RedisClient::DELETE )

      keys = [
        format( '%s-measurements', cachekey ),
        format( '%s-discovery'   , cachekey ),
        format( '%s-status'      , cachekey ),
        format( '%s-config'      , cachekey ),
        format( '%s-dns'         , cachekey ),
        cachekey
      ]

      @redis.del( *keys )
      status = remove_node( fqdn: fqdn, key: cachekey )
#       logger.debug( status )
      true
    end


    def dns_data(params)

      return false if( check_database == false )

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      fqdn    = params.dig(:fqdn)

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key(fqdn: fqdn )
      )

      result = @redis.get( cachekey )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      { ip: result.dig('ip'), short: result.dig('short'), fqdn: result.dig('fqdn') }
    end
    #
    # -- dns ------------------------------------



    # -- configurations -------------------------
    #

    def create_config(params, append = false )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      data = params.dig(:data)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key(fqdn: fqdn)
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

      to_store = { ip: ip, short: name, fqdn: fqdn, data: data, created: DateTime.now }.to_json
      @redis.set( cachekey, to_store )
    end


    def remove_config(params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      key  = params.dig(:key)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key(fqdn: fqdn)
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

        create_config( ip: ip, short: name, fqdn: fqdn, data: existing_data )
      end
    end


    def config(params)

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      key  = params.dig(:key)

      cachekey = format(
        '%s-config',
        Storage::RedisClient.cache_key(fqdn: fqdn)
      )

      result = @redis.get( cachekey )

      return { fqdn: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      if(key.nil?)
        result = result.dig('data').deep_string_keys
      else
        result = { key.to_s => result.dig('data', key.to_s) }
      end

      result
    end
    #
    # -- configurations -------------------------


    # -- discovery ------------------------------
    #
    def create_discovery(params, append = false )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      data = params.dig(:data)

      cachekey = format(
        '%s-discovery',
        Storage::RedisClient.cache_key(fqdn: fqdn)
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

      to_store = { ip: ip, short: name, fqdn: fqdn, data: data, created: DateTime.now }.to_json

      @redis.set( cachekey, to_store )
    end


    def discovery_data(params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      service = params.dig(:service)

      cachekey = format(
        '%s-discovery',
        Storage::RedisClient.cache_key(fqdn: fqdn )
      )

      result = @redis.get( cachekey )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      if (service.nil?)
        result = result.dig('data')
      else
        result = { service.to_sym => result.dig('data', service) }
      end

      result.deep_string_keys
    end
    #
    # -- discovery ------------------------------


    # -- measurements ---------------------------
    #
    def create_measurements(params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      data = params.dig(:data)

      cachekey = format(
        '%s-measurements',
        Storage::RedisClient.cache_key(fqdn: fqdn)
      )

      to_store = { ip: ip, short: name, fqdn: fqdn, data: data, created: DateTime.now }.to_json

      @redis.set( cachekey, to_store )
    end


    def measurements( params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      application  = params.dig(:application)

      cachekey = format(
        '%s-measurements',
        Storage::RedisClient.cache_key(fqdn: fqdn)
      )

      result = @redis.get( cachekey )

      return nil if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      return result.dig('data') if (application.nil?)

      { application.to_s: result.dig('data', application) }
    end
    #
    # -- measurements ---------------------------


    # -- nodes ----------------------------------
    #
    def add_node(params)

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      key  = params.dig(:key)

      cachekey = 'nodes'

      existing_data = @redis.get( cachekey )

      if (existing_data.nil?)
        data = { key.to_s => fqdn }
      else
        existing_data = JSON.parse(existing_data) if (existing_data.is_a?(String))

        data_org = existing_data.dig('data')

        if (data_org.nil?)
          data = { key.to_s => fqdn }
        else # transform a Array to Hash
          data_org = Hash[*data_org] if (data_org.is_a?(Array))

          founded_keys = data_org.keys

          # node already save -> GO OUT
          return if (founded_keys.include?(key.to_s) == true)

          data = data_org.merge({ key.to_s => fqdn })
        end
      end

      # transform hash keys to symbols
      data = data.deep_string_keys
      to_store = { data: data }.to_json

      @redis.set( cachekey, to_store )
    end


    def remove_node(params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)

      cachekey = 'nodes'

      existing_data = @redis.get( cachekey )
      existing_data = JSON.parse( existing_data ) if( existing_data.is_a?( String ) )
      data = existing_data.dig('data')
      data = data.tap { |hs,d| hs.delete(  Storage::RedisClient.cache_key(fqdn: fqdn ) ) }

      to_store = { data: data }.to_json

      @redis.set( cachekey, to_store )
    end


    def nodes( params = {} )

      return false if( check_database == false )

      ip   = params.dig(:ip)
      name = params.dig(:short)
      fqdn = params.dig(:fqdn)
      status    = params.dig(:status)  # Database::ONLINE

      status = status ? 0 : 1 if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )

      cachekey  = 'nodes'

      result    = @redis.get( cachekey )

      return false if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      unless( fqdn.nil? )

        result   = result.dig('data').values.select { |x| x == fqdn }
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
          d = self.status( { fqdn: k } ).deep_string_keys

          node_status = d.dig('status') || 0
          node_status = node_status ? 0 : 1 if( node_status.is_a?( TrueClass ) || node_status.is_a?( FalseClass ) )

          if( node_status.to_i == status.to_i )

            dns_data    = self.dns_data({ fqdn: k } )
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
    def set_status(params)

      return false if( check_database == false )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      status  = params.dig(:status) || 0

      status = status ? 0 : 1 if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )

      return { status: 404, message: 'missing fqdn hostname' }  if( fqdn.nil? )

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key(fqdn: fqdn)
      )

      result = @redis.get( cachekey )

      return { fqdn: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

      result['status'] = status
      result = result.to_json

      @redis.set( cachekey, result )
    end


    def status(params)

      return false if( check_database == false )

      ip      = params.dig(:ip)
      name    = params.dig(:short)
      fqdn    = params.dig(:fqdn)
      status  = params.dig(:status) || 0

      return { status: 404, message: 'missing fqdn hostname' } if( fqdn.nil? )

      cachekey = format(
        '%s-dns',
        Storage::RedisClient.cache_key( fqdn: fqdn )
      )

      result = @redis.get( cachekey )

      return { status: 0, created: nil } if( result.nil? )

      result = JSON.parse( result ) if( result.is_a?( String ) )

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

      { ip: ip, short: name, fqdn: fqdn, status: status, message: message, created: created }
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

