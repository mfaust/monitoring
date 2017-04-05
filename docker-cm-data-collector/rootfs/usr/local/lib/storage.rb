#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'dalli'
require 'sequel'
require 'redis'
require 'digest/md5'

require_relative 'logging'
require_relative 'tools'




# -----------------------------------------------------------------------------
# Monkey patches

# Modify `Object` (https://gist.github.com/Integralist/9503099)

# None of the above solutions work with a multi-level hash
# They only work on the first level: {:foo=>"bar", :level1=>{"level2"=>"baz"}}
# The following two variations solve the problem in the same way
# transform hash keys to symbols
# multi_hash = { 'foo' => 'bar', 'level1' => { 'level2' => 'baz' } }
# multi_hash = multi_hash.deep_symbolize_keys

class Object

  def deep_symbolize_keys

    if( self.is_a?( Hash ) )
      return self.inject({}) do |memo, (k, v)|
        memo.tap { |m| m[k.to_sym] = v.deep_symbolize_keys }
      end
    elsif( self.is_a?( Array ) )
      return self.map { |memo| memo.deep_symbolize_keys }
    end

#    if( self.is_a?( Hash ) )
#
#      puts 'is a hash'
#
#      r = self.reduce({}) do |memo, (k, v)|
#
#        memo.tap { |m| m[k.to_s.to_sym] = v.deep_symbolize_keys }
#      end
#
#      puts r
#      return r
#    end
#
#    if( self.is_a?( Array ) )
#
#      puts 'is a array'
#
#      r = self.reduce([]) do |memo, v|
#
#        memo << v.deep_symbolize_keys; memo
#      end
#
#      puts r
#      return r
#    end

    self
  end

end

# -----------------------------------------------------------------------------

module Storage


  class RedisClient

    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      logger.debug( params )

      @host   = params.dig(:redis, :host)
      @port   = params.dig(:redis, :port)     || 6379
      @db     = params.dig(:redis, :database) || 1

#       self.prepare()
    end

    def prepare()

      @redis = nil

      begin
        until( @redis != nil )

          logger.debug( 'try ...' )

          @redis = Redis.new(
            :host            => @host,
            :port            => @port,
            :db              => @db,
            :connect_timeout => 1.0,
            :read_timeout    => 1.0,
            :write_timeout   => 0.5
          )

#           sleep( 1 )
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




    def createDNS( params = {} )

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

      toStore = { ip: ip, shortname: short, longname: long, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

      self.setStatus( { :short => short, :status => 99 } )

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

    end


    def dnsData( params = {}  )

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

          data = data.deep_symbolize_keys

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
      configKey    = params.dig(:key)

      cachekey = sprintf(
        '%s-config',
        Storage::RedisClient.cacheKey( { :shortname => dnsShortname } )
      )

      # delete single config
      if( configKey != nil )

        existingData = @redis.get( cachekey )

        if( existingData.is_a?( String ) )
          existingData = JSON.parse( existingData )
        end

        data = existingData.dig('data').tap { |hs| hs.delete(configKey) }

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
      configKey    = params.dig(:key)

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


      if( configKey != nil )

        logger.debug( result )
        logger.debug( "data #{result.dig( 'data' )}" )

        result = {
          configKey.to_sym => result.dig( :data, configKey.to_sym )
        }
      else

        result = result.dig( 'data' ).deep_symbolize_keys

      end

      return result

    end



    def createDiscovery( params = {}, append = false )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      data         = params.dig(:data)

      cachekey = sprintf(
        '%s-discovery',
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
          data = data.deep_symbolize_keys

        end

      end

      toStore = { ip: dnsIp, shortname: dnsShortname, data: data, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

    end


    def discoveryData( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params.dig(:ip)
      short   = params.dig(:short)
      service = params.dig(:service)

      cachekey = sprintf(
        '%s-discovery',
        Storage::RedisClient.cacheKey( { :shortname => short } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :shortname => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      if( service != nil )
        result = { service.to_sym => result.dig( 'data', service ) }
      else
        result = result.dig( 'data' )
      end

      return result.deep_symbolize_keys

    end



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

      toStore = { shortname: dnsShortname, data: data, created: DateTime.now() }.to_json

      @redis.set( cachekey, toStore )

    end

    def measurements( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
#       key          = params.dig(:key)

      cachekey = sprintf(
        '%s-measurements',
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
      )

      result = @redis.get( cachekey )

      logger.debug( result )

      if( result == nil )
        return { :shortname => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end


      result = result.dig( 'data' ).deep_symbolize_keys

      return result

    end


    def nodes( params = {} )

    end

    def setStatus( params = {} )
      logger.debug( 'setStatus()' )
    end

    def status( params = {} )


    end


    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end

  end


  class Database

    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'

      self.prepare()
    end


    def prepare()

      @database = nil

      begin
        until( @database != nil )
#           logger.debug( 'try ...' )
          @database = Sequel.sqlite( sprintf( '%s/monitoring.db', @cacheDirectory ) )
          sleep( 3 )
        end
      rescue => e
        logger.error( e )
      end

      # @database.loggers << logger # Logger.new( $stdout, :debug )

      @database.create_table?( :dns ) {
        primary_key :id
        String      :ip        , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :shortname , :size => 60 , :key => true, :index => true, :unique => true, :null => false
        String      :longname  , :size => 250
        DateTime    :created   , :default => Time.now
        String      :checksum  , :size => 32
      }

      @database.create_table?( :config ) {
        primary_key :id
        String      :ip        , :size => 128 , :key => true, :index => true
        String      :shortname , :size => 60  , :key => true, :index => true
        String      :longname  , :size => 250
        String      :key       , :size => 128 , :key => true, :index => true, :null => false
        String      :value     , :text => true, :null => false
        DateTime    :created   , :default => Time.now()

#         index [ :ip, :shortname, :key ]
#         foreign_key [ :ip, :shortname, :key ], :name => 'unique_config'
      }

      @database.create_table?( :status ) {
        primary_key :id
        foreign_key :dns_id, :dns
        DateTime    :created   , :default => Time.now()
        DateTime    :updated   , :default => Time.now()
        Integer     :status

        index [ :dns_id, :status ]
      }

      @database.create_table?( :discovery ) {
        primary_key :id
        foreign_key :dns_id, :dns
        String      :service   , :size => 128 , :key => true, :index => true, :null => false
        Integer     :port      , :null => false
        String      :data      , :text => true, :null => false
        DateTime    :created   , :default => Time.now()
        DateTime    :updated   , :default => Time.now()

        index [ :dns_id, :service, :port ]
      }

      @database.create_table?( :measurements ) {
        primary_key :id
        foreign_key :dns_id, :dns
        foreign_key :discovery_id, :discovery
        String      :data      , :text => true, :null => false
        String      :checksum  , :size => 32
        DateTime    :created   , :default => Time.now()
        DateTime    :updated   , :default => Time.now()

        index [ :dns_id, :discovery_id ]
      }

      if( @database.table_exists?(:v_discovery) == false )
        @database.create_view( :v_discovery,
          'select
            dns.id as dns_id, dns.ip, dns.shortname, dns.created,
            discovery.*
          from
            dns as dns, discovery as discovery
          where
            dns.id = discovery.dns_id', :replace => true
        )
      end

      if( @database.table_exists?(:v_config) == false )
        @database.create_view( :v_config,
          'select
            dns.ip, dns.shortname, dns.longname, dns.checksum,
            config.id, config.key, config.value
          from
            dns as dns, config as config
          order by key', :replace => true
        )
      end

      if( @database.table_exists?(:v_status) == false )
        @database.create_view( :v_status,
          'select
            d.id as dns_id, d.ip, d.shortname, d.checksum,
            s.id, s.created, s.updated, s.status
          from
            dns as d, status as s
          where d.id = s.dns_id', :replace => true
        )
      end

      if( @database.table_exists?(:v_measurements) == false )
        @database.create_view( :v_measurements,
          'select
            dns.ip, dns.shortname,
            discovery.port, discovery.service,
            m.id, m.dns_id, m.discovery_id, m.checksum, m.data
          from
            dns as dns, discovery as discovery, measurements as m
          where
            dns.id = m.dns_id  and discovery.id = m.discovery_id
          order by
            m.id, m.dns_id, m.discovery_id', :replace => true
        )
      end

    end

    def checkDatabase()

      if( @database == nil )
        self.prepare()

        if( @database == nil )
          return false
        end
      end

    end



    # -- configurations -------------------------
    #
    def createConfig( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      dnsChecksum  = params.dig(:checksum)
      configKey    = params.dig(:key)
      configValues = params.dig(:value)
      data         = params.dig(:data)

      if( ( configKey == nil && configValues == nil ) && data.is_a?( Hash ) )

        data.each do |k,v|

          self.writeConfig( { :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :key => k, :value => v } )
        end
      else

        self.writeConfig( params )
      end

    end

    # PRIVATE
    def writeConfig( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      logger.debug( params )

      dnsIp        = params.dig(:ip)
      dnsShortname = params.dig(:short)
      dnsChecksum  = params.dig(:checksum)
      configKey    = params.dig(:key)
      configValues = params.dig(:value)

      if( dnsIp == nil && dnsShortname == nil )

        return false
      else

        rec = @database[:config].where(
          (
            ( Sequel[:ip        => dnsIp.to_s] ) |
            ( Sequel[:shortname => dnsShortname.to_s] )
          ) & (
            ( Sequel[:key   => configKey.to_s] ) &
            ( Sequel[:value => configValues.to_s] )
          )
        ).to_a

        if( rec.count() == 0 )

          if( dnsIp != nil )
            @database[:config].insert(
              :ip       => dnsIp.to_s,
              :key      => configKey.to_s,
              :value    => configValues.to_s,
              :created  => DateTime.now()
            )

          elsif( dnsShortname != nil )

            @database[:config].insert(
              :shortname => dnsShortname.to_s,
              :key       => configKey.to_s,
              :value     => configValues.to_s,
              :created   => DateTime.now()
            )
          end
        else

          # prüfen, ob 'value' identisch ist
          dbaValues    = rec.first[:value]
          configValues = configValues.to_s

          if( dbaValues != configValues )

            if( dnsIp != nil )

              @database[:config].where(
                ( Sequel[:ip  => dnsIp.to_s] ) &
                ( Sequel[:key => configKey.to_s] )
              ).update(
                :value      => configValues.to_s,
                :created    => DateTime.now()
              )
            elsif( dnsShortname != nil )

              @database[:config].where(
                ( Sequel[:shortname => dnsShortname.to_s] ) &
                ( Sequel[:key       => configKey.to_s] )
              ).update(
                :value      => configValues.to_s,
                :created    => DateTime.now()
              )
            end
          end
        end
      end
    end


    def removeConfig( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip        = params[ :ip ]    ? params[ :ip ]    : nil
      short     = params[ :short ] ? params[ :short ] : nil
      long      = params[ :long ]  ? params[ :long ]  : nil
      configKey = params[ :key ]   ? params[ :key ]   : nil

      rec = @database[:config].select(:shortname).where(
        ( Sequel[:ip        => ip.to_s] ) |
        ( Sequel[:shortname => short.to_s] ) |
        ( Sequel[:longname  => long.to_s] )
      ).to_a

      if( rec.count() != 0 )

        shortname = rec.first[:shortname]

        if( configKey == nil )

          @database[:config].where( Sequel[:shortname => shortname] ).delete
        else
          @database[:config].where(
            ( Sequel[:shortname   => shortname] ) &
            ( Sequel[:key  => configKey] )
          ).delete
        end
      end
    end


    def config( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip        = params[ :ip ]    ? params[ :ip ]    : nil
      short     = params[ :short ] ? params[ :short ] : nil
      long      = params[ :long ]  ? params[ :long ]  : nil
      configKey = params[ :key ]   ? params[ :key ]   : nil

      array     = Array.new()
      result    = Hash.new()

      def dbaData( w )

        return  @database[:v_config].select( :ip, :shortname, :checksum, :key, :value ).where( w ).to_a

      end

      if( configKey == nil )

        w = (
          ( Sequel[:ip        => ip.to_s] ) |
          ( Sequel[:shortname => short.to_s] ) |
          ( Sequel[:longname  => long.to_s] )
        )

      else

        w = (
          ( Sequel[:ip        => ip.to_s] ) |
          ( Sequel[:shortname => short.to_s] ) |
          ( Sequel[:longname  => long.to_s] )
        ) & (
          ( Sequel[:key => configKey.to_s] )
        )

      end

      def collectValues( hashes )

        {}.tap{ |r| hashes.each{ |h| h.each{ |k,v| ( r[k]||=[] ) << v } } }
      end

      rec = self.dbaData( w )

      if( rec.count() != 0 )

        dnsShortName  = rec.first.dig( :checksum ).to_s

        result[dnsShortName.to_s] ||= {}
        result[dnsShortName.to_s]['dns'] ||= {}
        result[dnsShortName.to_s]['dns']['ip']        = rec.first.dig( :ip ).to_s
        result[dnsShortName.to_s]['dns']['shortname'] = rec.first.dig( :shortname ).to_s

        groupByKey = rec.group_by { |k| k[:key] }

        groupByKey.each do |g,v|

          c = collectValues(
            v.map do |hash|
              { value: parsedResponse( hash[:value] ) }
            end
          )

          values = c.select { |h| h['value'] }

          result[dnsShortName.to_s][g.to_s] ||= {}
          result[dnsShortName.to_s][g.to_s] = values[:value].flatten.sort

          array << result
        end
      else
        return false
      end

      array = array.reduce( :merge )

      return array

    end
    #
    # -- configurations -------------------------


    # -- dns ------------------------------------
    #
    def createDNS( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil

      dns     = @database[:dns]

      rec = dns.select(:id).where(
        :ip        => ip.to_s,
        :shortname => short.to_s,
        :longname  => long.to_s
      ).to_a.first

      # insert if data not found
      if( rec == nil )

        insertedId = dns.insert(
          :ip        => ip.to_s,
          :shortname => short.to_s,
          :longname  => long.to_s,
          :checksum  => Digest::MD5.hexdigest( [ ip, short, long ].join ),
          :created   => DateTime.now()
        )

        self.setStatus( { :dns_id => insertedId, :ip => ip, :short => short, :status => 99 } )

      end

    end


    def removeDNS( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil

      rec = @database[:dns].select( :id ).where(
        ( Sequel[:ip        => ip.to_s] ) |
        ( Sequel[:shortname => short.to_s] ) |
        ( Sequel[:longname  => long.to_s] )
      ).to_a

      if( rec.count() != 0 )

        id = rec.first[:id].to_i

        self.setStatus( { :dns_id => id, :status => 99 } )

        @database[:measurements].where( Sequel[:dns_id => id] ).delete
        @database[:discovery].where( Sequel[:dns_id => id] ).delete
        @database[:status].where( Sequel[:dns_id => id] ).delete
        @database[:dns].where( Sequel[:id => id] ).delete

      end

    end


    def dnsData( params = {}  )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil

      dns = @database[:dns]

      rec = dns.where(
        (Sequel[:ip        => ip.to_s] ) |
        (Sequel[:shortname => short.to_s] ) |
        (Sequel[:longname  => long.to_s] )
      ).to_a

      if( rec.count() == 0 )
        return nil
      else

        return {
          :id        => rec.first[:id].to_i,
          :ip        => rec.first[:ip].to_s,
          :shortname => rec.first[:shortname].to_s,
          :longname  => rec.first[:longname].to_s,
          :created   => rec.first[:created].to_s,
          :checksum  => rec.first[:checksum].to_s
        }

      end
    end
    #
    # -- dns ------------------------------------


    # -- discovery ------------------------------
    #
    def createDiscovery( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsId        = params[ :id ]       ? params[ :id ]       : nil
      dnsIp        = params[ :ip ]       ? params[ :ip ]       : nil
      dnsShortname = params[ :short ]    ? params[ :short ]    : nil
      dnsChecksum  = params[ :checksum ] ? params[ :checksum ] : nil
      port         = params[ :port ]     ? params[ :port ]     : nil
      service      = params[ :service ]  ? params[ :service ]  : nil
      data         = params[ :data ]     ? params[ :data ]     : nil

      if( service == nil && data.is_a?( Hash ) )

        data.each do |k,v|

          p = v.dig( 'port' )
#           logger.debug( sprintf( '%s - %s - %s', dnsShortname, p, k ) )

          self.writeDiscovery( { :id => dnsId, :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :port => p, :service => k, :data => v } )

        end

      else
        self.writeDiscovery( params )
      end

    end

    # PRIVATE
    def writeDiscovery( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsId        = params[ :id ]       ? params[ :id ]       : nil
      dnsIp        = params[ :ip ]       ? params[ :ip ]       : nil
      dnsShortname = params[ :short ]    ? params[ :short ]    : nil
      dnsChecksum  = params[ :checksum ] ? params[ :checksum ] : nil
      port         = params[ :port ]     ? params[ :port ]     : nil
      service      = params[ :service ]  ? params[ :service ]  : nil
      data         = params[ :data ]     ? params[ :data ]     : nil

      discovery = @database[:discovery]

      rec = discovery.where(
        (Sequel[:dns_id   => dnsId.to_i] ) &
        (Sequel[:service  => service.to_s] )
      ).to_a

      if( rec.count() == 0 )

        return discovery.insert(

          :dns_id     => dnsId.to_i,
          :port       => port.to_i,
          :service    => service,
          :data       => data.to_s,
          :created    => DateTime.now()
        )

      end

    end


    def discoveryData( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]      ? params[ :ip ]      : nil
      short   = params[ :short ]   ? params[ :short ]   : nil
      service = params[ :service ] ? params[ :service ] : nil

      array     = Array.new()
      result    = Hash.new()

      if( ( ip != nil || short != nil ) )

        if( ip != nil )
          host = ip
        end
        if( short != nil )
          host = short
        end
      else
        host = nil
      end

      # ---------------------------------------------------------------------------------

      def dbaData( w )

        return  @database[:v_discovery].select( :dns_id, :id, :ip, :shortname, :created, :service, :port, :data ).where( w ).to_a

      end

      # ---------------------------------------------------------------------------------

      if( service == nil && host == nil )

        logger.error( '( service == nil && host == nil )' )

        rec = self.dbaData( nil )

        groupByHost = rec.group_by { |k| k[:shortname] }

        return groupByHost.keys

      #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
      elsif( service != nil && host == nil )

#         logger.debug( '( service != nil && host == nil )' )
        w = ( Sequel[:service => service.to_s] )

        rec = self.dbaData( w )

        result[service.to_s] ||= {}

        rec.each do |data|

          dnsShortName  = data.dig( :shortname ).to_s
          service       = data.dig( :service ).to_s
          dnsId         = data.dig( :dns_id ).to_i
          discoveryId   = data.dig( :id ).to_i
          discoveryData = data.dig( :data )

          result[service.to_s][dnsShortName] ||= {}
          result[service.to_s][dnsShortName] = {
            :dns_id       => dnsId,
            :discovery_id => discoveryId,
            :data         => self.parsedResponse( discoveryData.gsub( '=>', ':' ) )
          }

          array << result

        end

        array = array.reduce( :merge )

        return array

      # { :short => 'monitoring-16-01' }
      # { :ip => '10.2.14.156' }
      elsif( service == nil && host != nil )

        w = ( Sequel[:ip => ip.to_s] ) | ( Sequel[:shortname => short.to_s] )

        rec = self.dbaData( w )

        result[host.to_s] ||= {}

        rec.each do |data|

          dnsShortName  = data.dig( :dns_shortname ).to_s
          service       = data.dig( :service ).to_s
          dnsId         = data.dig( :dns_id ).to_i
          discoveryId   = data.dig( :id ).to_i
          discoveryData = data.dig( :data )

          result[host.to_s][service] ||= {}
          result[host.to_s][service] = {
            :dns_id       => dnsId,
            :discovery_id => discoveryId,
            :data         => self.parsedResponse( discoveryData.gsub( '=>', ':' ) )
          }

          array << result
        end

        array = array.reduce( :merge )

#         logger.debug( JSON.pretty_generate( array ) )

        return array

      elsif( service != nil && host != nil )

#         logger.debug( '( service != nil && host != nil )' )
        w = (
          (Sequel[:ip => ip.to_s] ) |
          (Sequel[:shortname => short.to_s] )
        ) & (
          (Sequel[:service => service.to_s] )
        )

        rec = self.dbaData( w )

        if( rec.count() == 0 )
          return nil
        else
          result[host.to_s] ||= {}

          dnsId         = rec.first[:dns_id].to_i
          discoveryId   = rec.first[:id].to_i
          discoveryData = rec.first[:data]

          result[host.to_s][service] ||= {}
          result[host.to_s][service] = {
            :dns_id       => dnsId,
            :discovery_id => discoveryId,
            :data         => self.parsedResponse( discoveryData.gsub( '=>', ':' ) )
          }

          array << result
          array = array.reduce( :merge )

          return array
        end

      end

      return nil

    end
    #
    # -- discovery ------------------------------


    def createMeasurements( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsId        = params[ :dns_id ]       ? params[ :dns_id ]       : nil
      discoveryId  = params[ :discovery_id ] ? params[ :discovery_id ] : nil
      data         = params[ :data ]         ? params[ :data ]         : nil

      if( dnsId == nil || discoveryId == nil )

        logger.error( 'wrong data' )
        return {}
      end

      checksum = Digest::MD5.hexdigest( [ dnsId.to_i, discoveryId.to_i, data ].join('-') )

      measurements = @database[:measurements]

      rec = measurements.select( :dns_id, :discovery_id, :checksum ).where(
        :dns_id       => dnsId.to_s,
        :discovery_id => discoveryId.to_i
      ).to_a

      if( rec.count() == 0 )

        return measurements.insert(

          :dns_id       => dnsId.to_i,
          :discovery_id => discoveryId.to_i,
          :data         => data.to_s,
          :checksum     => checksum,
          :created      => DateTime.now()
        )
      else

        dbaChecksum = rec.first[:checksum].to_s

#         logger.debug( checksum )
#         logger.debug( dbaChecksum )

        if( dbaChecksum != checksum )

          measurements.where(
           ( Sequel[:dns_id       => dnsId.to_i] ) &
           ( Sequel[:discovery_id => discoveryId.to_i] )
          ).update(
            :checksum  => checksum,
            :data      => data.to_s,
            :updated   => DateTime.now()
          )

        elsif( dbaChecksum == checksum )

#           logger.debug( 'identical data' )
          return
        else
          #
        end
      end

    end


    def measurements( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]      ? params[ :ip ]      : nil
      short   = params[ :short ]   ? params[ :short ]   : nil
      service = params[ :service ] ? params[ :service ] : nil

      array     = Array.new()
      result    = Hash.new()

      if( ( ip != nil || short != nil ) )

        if( ip != nil )
          host = ip
        end
        if( short != nil )
          host = short
        end
      else
        host = nil
      end

      # ---------------------------------------------------------------------------------

      def dbaData( w )

        return  @database[:v_measurements].select(:ip, :shortname, :service, :port, :data).where( w ).to_a

      end

      if( service == nil && host == nil )

        # TODO
        logger.error( '( service == nil && host == nil )' )
#
#         rec = self.dbaData( nil )
#
#         groupByHost = rec.group_by { |k| k[:shortname] }
#
#         return groupByHost.keys

      #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
      elsif( service != nil && host == nil )

        # TODO
#         logger.debug( '( service != nil && host == nil )' )

      # { :short => 'monitoring-16-01' }
      # { :ip => '10.2.14.156' }
      elsif( service == nil && host != nil )

#         logger.debug( '( service == nil && host != nil )' )

        w = ( Sequel[:ip => ip.to_s] ) | ( Sequel[:shortname => short.to_s] )

        rec = self.dbaData( w )

        if( rec.count() == 0 )
          return nil
        else

          result[host.to_s] ||= {}

          rec.each do |data|

            dnsIp         = data.dig( :ip ).to_s
            dnsShortName  = data.dig( :shortname ).to_s
            service       = data.dig( :service ).to_s
            port          = data.dig( :port ).to_i
            measurements  = data.dig( :data )

            result[host.to_s][service.to_s] ||= {}
            result[host.to_s][service.to_s] = {
              :service  => service,
              :port     => port,
              :data     => self.parsedResponse( measurements.gsub( '=>', ':' ) )
            }

            array << result
          end

          array = array.reduce( :merge )

#           logger.debug( JSON.pretty_generate( array ) )
        end
        return array

      # { :short => nil, :service => nil }
      elsif( service != nil && host != nil )

        # TODO
#         logger.debug( '( service != nil && host != nil )' )

      end

      return nil

    end



    def nodes( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      status    = params[ :status ]    ? params[ :status ]    : nil # Database::ONLINE

      result    = nil

      if( status != nil )
        w = ( Sequel[:status => status ] )
      else
        w = nil
      end

      rec = @database[:v_status].select().where( w ) .to_a

      if( rec.count() != 0 )

        groupByHost = rec.group_by { |k| k[:shortname] }

        return groupByHost
      end

      return Hash.new()

    end


    def setStatus( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      dnsId   = params[ :dns_id ] ? params[ :dns_id ] : nil
      ip      = params[ :ip ]     ? params[ :ip ]     : nil
      short   = params[ :short ]  ? params[ :short ]  : nil
      long    = params[ :long ]   ? params[ :long ]   : nil
      status  = params[ :status ] ? params[ :status ] : 0

      if( ip == nil || short == nil )
        return
      end

      # shortway insert ...
      if( dnsId != nil )

        @database[:status].insert(
          :dns_id   => dnsId.to_i,
          :status   => status
        )
        return
      end

      # check existing status entry
      rec = @database[:v_status].select(:id, :dns_id).where(
        Sequel[:ip        => ip.to_s] |
        Sequel[:shortname => short.to_s]
      ).to_a

      if( rec.count() == 0 )

        # get dns data to prper create entry
        dnsData = self.dnsData( { :ip => ip, :short => short } )

        statusId  = rec.first[:id].to_i
        dnsId     = rec.first[:dns_id].to_i

        @database[:status].insert(
          :dns_id   => dnsId.to_i,
          :status   => status
        )

      else

        # update status
        statusId  = rec.first[:id].to_i
        dnsId     = rec.first[:dns_id].to_i

        @database[:status].where(
          ( Sequel[:id     => statusId] &
            Sequel[:dns_id => dnsId]
          )
        ).update(
          :status     => status,
          :updated    => DateTime.now()
        )
      end

    end


    def status( params = {} )

      if( self.checkDatabase() == false )
        return false
      end

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil


      rec = @database[:v_status].select( :ip, :shortname, :created, :status ).where(
        Sequel[:ip        => ip.to_s] | Sequel[:shortname => short.to_s]
      ).to_a

      if( rec.count() == 0 )
        return nil
      else

        return {
          :ip        => rec.first[:ip].to_s,
          :shortname => rec.first[:shortname].to_s,
          :created   => rec.first[:created].to_s,
          :status    => rec.first[:status].to_i
        }

      end

    end


    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end

  end


  class Memcached

    include Logging

    def initialize( params = {} )

      host      = params[:host]      ? params[:host]      : 'localhost'
      port      = params[:port]      ? params[:port]      : 11211
      namespace = params[:namespace] ? params[:namespace] : 'monitoring'
      expire    = params[:expire]    ? params[:expire]    : 10

      memcacheOptions = {
        :compress   => true,
        :namespace  => namespace.to_s
      }

      if( expire.to_i != 0 )
        memcacheOptions[:expires_in] = ( 60 * expire.to_i )  # :expires_in - default TTL in seconds (defaults to 0 or forever)
      end

      @mc = nil

      begin
        until( @mc != nil )
#           logger.debug( 'try ...' )
          @mc = Dalli::Client.new( sprintf( '%s:%s', host, port ), memcacheOptions )
          sleep( 3 )
        end
      rescue => e
        logger.error( e )
      end
    end

    def self.cacheKey( params = {} )

      params   = Hash[params.sort]
      checksum = Digest::MD5.hexdigest( params.to_s )

      return checksum

    end

    def get( key )

      result = {}

      if( @mc )
#         logger.debug( @mc.stats( :items ) )
#         sleep(4)
        result = @mc.get( key )
      end

      return result
    end

    def set( key, value )

      return @mc.set( key, value )
    end

    def self.delete( key )

      return @mc.delete( key )
    end

  end


end

# ---------------------------------------------------------------------------------------

# EOF
