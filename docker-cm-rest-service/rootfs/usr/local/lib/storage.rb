#
#
#

require 'rubygems'
require 'json'
require 'redis'
require 'digest/md5'

require_relative 'monkey'
require_relative 'logging'

# ---------------------------------------------------------------------------------------

module Storage

  class RedisClient

    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      @host   = params.dig(:redis, :host)
      @port   = params.dig(:redis, :port)     || 6379
      @db     = params.dig(:redis, :database) || 1

      self.prepare()
    end


    def prepare()

      @redis = nil

      begin
        until( @redis != nil )

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
        logger.error( e )
      end


    end


    def checkDatabase()

      if( @redis == nil )
        self.prepare()

        if( @redis == nil )
          return false
        end
      end

    end


    def self.cacheKey( params = {} )

      params   = Hash[params.sort]
      checksum = Digest::MD5.hexdigest( params.to_s )

      return checksum

    end


    def get( key )

      data =  @redis.get( key )

      if( data == nil )
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
          logger.error( e )
        end

#         data = JSON.parse( data, :quirks_mode => true )
      end

      return data.deep_string_keys

    end


    def set( key, value )

      return @redis.set( key, value )
    end


    def delete( key )

      return @redis.delete( key )
    end


    # -- dns ------------------------------------
    #
    def createDNS( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      long    = params.dig(:long)

      cachekey = Storage::RedisClient.cacheKey( { :short => short } )

      toStore = { ip: ip, shortname: short, longname: long, created: DateTime.now() }.to_json

      @redis.set( sprintf( '%s-dns', cachekey ), toStore )

      self.setStatus( { :short => short, :status => 99 } )

      self.addNode( { :short => short, :key => cachekey } )

    end


    def removeDNS( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      long    = params.dig(:long)

      cachekey = Storage::RedisClient.cacheKey( { :short => short } )

      self.setStatus( { :short => short, :status => 99 } )

      @redis.del( sprintf( '%s-measurements', cachekey ) )
      @redis.del( sprintf( '%s-discovery'   , cachekey ) )
      @redis.del( sprintf( '%s-status'      , cachekey ) )
      @redis.del( sprintf( '%s-dns'         , cachekey ) )
      @redis.del( cachekey )

      self.removeNode( { :short => short, :key => cachekey } )

    end


    def dnsData( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      long    = params.dig(:long)

      cachekey = sprintf(
        '%s-dns',
        Storage::RedisClient.cacheKey( { :short => short } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :ip => nil, :shortname => nil, :longname => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      return {
        :ip        => result.dig('ip'),
        :shortname => result.dig('shortname'),
        :longname  => result.dig('longname')
      }
    end
    #
    # -- dns ------------------------------------



    # -- configurations -------------------------
    #

    def createConfig( params = {}, append = false )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = sprintf(
        '%s-config',
        Storage::RedisClient.cacheKey( { :shortname => dnsShortname } )
      )

      if( append == true )

        existingData = @redis.get( cachekey )

        if( existingData != nil )

          if( existingData.is_a?( String ) )
            existingData = JSON.parse( existingData )
          end

          dataOrg = existingData.dig('data')

          if( dataOrg.is_a?( Array ) )

            # transform a Array to Hash
            dataOrg = Hash[*dataOrg]

          end

          data = dataOrg.merge( data )

          # transform hash keys to symbols

          data = data.deep_string_keys

#          data = data.reduce({}) do |memo, (k, v)|
#            memo.merge({ k.to_sym => v})
#          end

        end

      end

      toStore = { ip: dnsIp, shortname: dnsShortname, data: data, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

    end


    def removeConfig( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      key    = params.dig(:key)

      cachekey = sprintf(
        '%s-config',
        Storage::RedisClient.cacheKey( { :shortname => dnsShortname } )
      )

      # delete single config
      if( key != nil )

        existingData = @redis.get( cachekey )

        if( existingData.is_a?( String ) )
          existingData = JSON.parse( existingData )
        end

        data = existingData.dig('data').tap { |hs| hs.delete(key) }

        existingData['data'] = data

        self.createConfig( { :short => dnsShortname, :data => existingData } )

      else

        # remove all data
        @redis.del( cachekey )
      end

    end


    def config( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      key    = params.dig(:key)

      cachekey = sprintf(
        '%s-config',
        Storage::RedisClient.cacheKey( { :shortname => dnsShortname } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :shortname => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end


      if( key != nil )

        result = {
          key.to_sym => result.dig( :data, key.to_sym )
        }
      else

        result = result.dig( 'data' ).deep_string_keys

      end

      return result

    end
    #
    # -- configurations -------------------------


    # -- discovery ------------------------------
    #
    def createDiscovery( params = {}, append = false )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = sprintf(
        '%s-discovery',
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
      )

      if( append == true )

        existingData = @redis.get( cachekey )

        if( existingData != nil )

          if( existingData.is_a?( String ) )
            existingData = JSON.parse( existingData )
          end

          dataOrg = existingData.dig('data')

          if( dataOrg.is_a?( Array ) )

            # transform a Array to Hash
            dataOrg = Hash[*dataOrg]

          end

          data = dataOrg.merge( data )

          # transform hash keys to symbols
          data = data.deep_string_keys

        end

      end

      toStore = { short: dnsShortname, data: data, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

    end


    def discoveryData( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short   = params.dig(:short)
      service = params.dig(:service)

      cachekey = sprintf(
        '%s-discovery',
        Storage::RedisClient.cacheKey( { :short => short } )
      )

      result = @redis.get( cachekey )

      logger.debug( result )

      if( result == nil )
        return { :short => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      if( service != nil )
        result = { service.to_sym => result.dig( 'data', service ) }
      else
        result = result.dig( 'data' )
      end

      return result.deep_string_keys

    end
    #
    # -- discovery ------------------------------


    # -- measurements ---------------------------
    #
    def createMeasurements( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = sprintf(
        '%s-measurements',
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
      )

      toStore = { short: dnsShortname, data: data, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

    end


    def measurements( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      application  = params.dig(:application)

      cachekey = sprintf(
        '%s-measurements',
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :short => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      if( application != nil )

        result = { application => result.dig( 'data', application ) }
      else
        result = result.dig( 'data' )
      end

      return result

    end
    #
    # -- measurements ---------------------------


    # -- nodes ----------------------------------
    #
    def addNode( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short  = params.dig(:short)
      key    = params.dig(:key)

      cachekey = 'nodes'

      existingData = @redis.get( cachekey )

      if( existingData != nil )

        if( existingData.is_a?( String ) )
          existingData = JSON.parse( existingData )
        end

        dataOrg = existingData.dig('data')

        if( dataOrg == nil )

          data = { key.to_s => short }

        else

          if( dataOrg.is_a?( Array ) )

            # transform a Array to Hash
            dataOrg = Hash[*dataOrg]
          end

          foundedKeys = dataOrg.keys

          if( foundedKeys.include?( key.to_s ) == false )

            data = dataOrg.merge( { key.to_s => short } )
          else

            # node already save -> GO OUT
            return
          end

        end

      else

        data = { key.to_s => short }

      end

      # transform hash keys to symbols
      data = data.deep_string_keys

      toStore = { data: data }.to_json

      @redis.set( cachekey, toStore )

    end


    def removeNode( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short  = params.dig(:short)
#       key    = params.dig(:key) || 'nodes'

      # delete single config
      #
#       if( key != nil )

        existingData = @redis.get( 'nodes' )

        logger.debug( existingData )

        if( existingData.is_a?( String ) )
          existingData = JSON.parse( existingData )
        end

        logger.debug( existingData )

        data = existingData.dig('data').tap { |hs| hs.delete(key) }

        existingData['data'] = data

        self.createConfig( { :short => short, :data => existingData } )

#       else

        # remove all data
#         @redis.del( key )
#       end

    end


    def nodes( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short     = params.dig(:short)
      status    = params.dig(:status)  # Database::ONLINE

      if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )
        status = status ? 0 : 1
      end

      cachekey  = 'nodes'

      result    = @redis.get( cachekey )

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      if( short != nil )

        result   = result.dig('data').values.select { |x| x == short }

        return result.first.to_s

      end

      if( status != nil )

        keys   = result.dig('data').values

        result = Hash.new()

        keys.each do |k|

          d = self.status( { :short => k } ).deep_string_keys

          nodeStatus = d.dig('status') || 0

          if( nodeStatus.is_a?( TrueClass ) || nodeStatus.is_a?( FalseClass ) )
            nodeStatus = nodeStatus ? 0 : 1
          end

          if( nodeStatus.to_i == status.to_i )

            dnsData    = self.dnsData( { :short => k } )
#             statusData = self.status( { :short => k } )

#             logger.debug( statusData )

            result[k.to_s] ||= {}
            result[k.to_s] = dnsData

          end
        end

        return result

      end

      #
      #
      return result.dig('data').values

    end
    #
    # -- nodes ----------------------------------

    # -- status ---------------------------------
    #
    def setStatus( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short   = params.dig(:short)
      status  = params.dig(:status) || 0

      if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )
        status = status ? 0 : 1
      end

      if( short == nil )
        return {
          :status  => 404,
          :message => 'missing short hostname'
        }
      end

      cachekey = sprintf(
        '%s-dns',
        Storage::RedisClient.cacheKey( { :short => short } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return {
          :short => nil
        }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      result['status'] = status
      result = result.to_json

      @redis.set( cachekey, result )

    end


    def status( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      short   = params.dig(:short)
      status  = params.dig(:status) || 0

      if( short == nil )
        return {
          :status  => 404,
          :message => 'missing short hostname'
        }
      end

      cachekey = sprintf(
        '%s-dns',
        Storage::RedisClient.cacheKey( { :short => short } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :status  => 0, :created => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      status   = result.dig( 'status' ) || 0
      created  = result.dig( 'created' )

      if( status.is_a?( TrueClass ) || status.is_a?( FalseClass ) )
        status = status ? 0 :1
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


      return {
        :short   => short,
        :status  => status,
        :created => created
      }
    end
    #
    # -- status ---------------------------------

    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end

  end

end

# ---------------------------------------------------------------------------------------

# EOF
