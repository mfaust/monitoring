#!/usr/bin/ruby

require 'rubygems'
require 'json'
# require 'dalli'
# require 'sequel'
# require 'redis'
require 'mysql2'
require 'digest/md5'

require_relative 'monkey'
require_relative 'logging'
require_relative 'tools'


# -----------------------------------------------------------------------------
#
# 2017-04-11 - 09:30
#
# -----------------------------------------------------------------------------

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

      return @redis.del( key )
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

      keys = [
        sprintf( '%s-measurements', cachekey ),
        sprintf( '%s-discovery'   , cachekey ),
        sprintf( '%s-status'      , cachekey ),
        sprintf( '%s-config'      , cachekey ),
        sprintf( '%s-dns'         , cachekey ),
        cachekey
      ]

      @redis.del( *keys )

#       @redis.del( sprintf( '%s-measurements', cachekey ) )
#       @redis.del( sprintf( '%s-discovery'   , cachekey ) )
#       @redis.del( sprintf( '%s-status'      , cachekey ) )
#       @redis.del( sprintf( '%s-dns'         , cachekey ) )
#       @redis.del( cachekey )

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
        return nil # { :ip => nil, :short => nil, :longname => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      return {
        :ip        => result.dig('ip'),
        :short     => result.dig('shortname'),
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
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
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
      key          = params.dig(:key)

      cachekey = sprintf(
        '%s-config',
        Storage::RedisClient.cacheKey( { :short => dnsShortname } )
      )

      result = @redis.get( cachekey )

      if( result == nil )
        return { :short => nil }
      end

      if( result.is_a?( String ) )
        result = JSON.parse( result )
      end

      if( key != nil )

        result = {
          key.to_s => result.dig( 'data', key.to_s )
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

#       logger.debug( params )

      cachekey = 'nodes'

      existingData = @redis.get( cachekey )

      if( existingData.is_a?( String ) )
        existingData = JSON.parse( existingData )
      end

      data = existingData.dig('data')
      data = data.tap { |hs,d| hs.delete(  Storage::RedisClient.cacheKey( { :short => short } ) ) }

#       existingData['data'] = data

      # transform hash keys to symbols
#       data = data.deep_string_keys

      toStore = { data: data }.to_json

#       logger.debug( toStore )

      @redis.set( cachekey, toStore )

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

            result[k.to_s] ||= {}
            result[k.to_s] = dnsData

          end

        end

        return result

      end

      #
      #
      result   = result.dig('data').values

      return result


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


  class MySQL

    include Logging

    OFFLINE  = 0
    ONLINE   = 1
    DELETE   = 98
    PREPARE  = 99

    def initialize( params = {} )

      host            = params.dig(:mysql, :host)
      user            = params.dig(:mysql, :user)
      pass            = params.dig(:mysql, :password)
      @schema         = params.dig(:mysql, :schema)
      read_timeout    = params.dig(:mysql, :timeout, :read)    || 5
      write_timeout   = params.dig(:mysql, :timeout, :write)   || 5
      connect_timeout = params.dig(:mysql, :timeout, :connect) || 5

      @client     = nil

      begin

        until( @client != nil )

          @client = Mysql2::Client.new(
            :host            => host,
            :username        => user,
            :password        => pass,
            :database        => @schema,
            :read_timeout    => read_timeout,
            :write_timeout   => write_timeout,
            :connect_timeout => connect_timeout,
            :encoding        => 'utf8',
            :reconnect       => true
          )

          logger.info( 'create database connection' )
          sleep( 3 )
        end
      rescue Exception => e
        logger.error( "An error occurred for connection: #{e}" )

        raise( e )
      rescue => e
        logger.error( e )

        raise( e )
      end

      # SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'DBName'
      @client.query('SET storage_engine=InnoDB')
      @client.query("CREATE DATABASE if not exists #{@schema}")

      self.prepare()

    end


    def prepare()

      @client.query( "USE #{@schema}" )

      @client.query(
        "CREATE TABLE IF NOT EXISTS dns (
          id         int(11) not null AUTO_INCREMENT,
          ip         varchar(16) not null default '',
          name       varchar(160) not null default '',
          fqdn       varchar(160) not null default '',
          status     enum('offline','online','delete','prepare','unknown') default 'unknown',
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`ID`),
          key(`ip`) )"
      )

      @client.query(
        "CREATE TABLE IF NOT EXISTS config (
          `key`      varchar(128),
          `value`    text not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          KEY(`key`),
          FOREIGN KEY (`dns_ip`)
          REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )"
      )

      @client.query(
        "CREATE TABLE IF NOT EXISTS discovery (
          service    varchar(128) not null,
          port       int(4) not null,
          data       text not null,
          dns_ip     varchar(16),
          creation   DATETIME DEFAULT   CURRENT_TIMESTAMP,
          changed    DATETIME ON UPDATE CURRENT_TIMESTAMP,
          KEY(`service`),
          FOREIGN KEY (`dns_ip`)
          REFERENCES dns(`ip`)
          ON DELETE CASCADE
        )"
      )

    end

    def toJson( data )

      h = Hash.new()

      data.each do |k|

        # "Variable_name"=>"Innodb_buffer_pool_pages_free", "Value"=>"1"
        h[k['Variable_name']] =  k['Value']
      end

      return h

    end

    # -- dns ------------------------------------
    #
    def createDNS( params = {} )

      if( ! @client )
        return false
      end

      logger.debug( " createDNS( #{params} )")

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT count(ip) as count FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#      logger.debug( statement )
#      logger.debug( result.to_a )

      if( result.to_a.first.dig('count').to_i == 0 )

        statement = sprintf('insert into dns ( ip, name, fqdn, status ) values ( \'%s\', \'%s\', \'%s\', \'prepare\' )', ip, name, fqdn )
        result    = @client.query( statement, :as => :hash )

        logger.debug( result.to_a )
      end
    end


    def removeDNS( params = {} )

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('delete FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

#      logger.debug( statement )
#      logger.debug( result.to_a )
    end


    def dnsData( params = {}  )

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      statement = sprintf('SELECT ip, name, fqdn FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
#      logger.debug( statement )
      result    = @client.query( statement, :as => :hash )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      return nil

    end
    #
    # -- dns ------------------------------------


    def nodes( params = {} )

      if( ! @client )
        return false
      end

      result = Array.new
      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE

      logger.debug( " nodes( #{params} )")

      w = Array.new

      if( ip != nil )
        w << sprintf( 'ip like \'%%%s%%\'', ip )
      end
      if( name != nil )
        w << sprintf( 'name like \'%%%s%%\'', name )
      end
      if( fqdn != nil )
        w << sprintf( 'fqdn like \'%%%s%%\'', fqdn )
      end
      if( status != nil )

        status = case status
          when Storage::MySQL::ONLINE
            'online'
          when  Storage::MySQL::OFFLINE
            'offline'
          when Storage::MySQL::DELETE
            'delete'
          when Storage::MySQL::PREPARE
            'prepare'
          else
            'unknown'
          end
        w << sprintf( 'status = \'%s\'', status )
      end

      if( w.count != 0 )
        w = w.join( ' or ' )
        w = sprintf( 'where %s', w )
      else
        w = nil
      end

      statement = sprintf('SELECT ip, name, fqdn, status FROM dns %s', w  )

#       logger.debug( statement )

      res    = @client.query( statement, :as => :hash )

      if( res.count != 0 )

        headers = res.fields # <= that's an array of field names, in order
        res.each(:as => :hash) do |row|

          result << row.dig('fqdn')
#           logger.debug( row )
        end

        return result
      end

      return nil



      rec = @database[:v_status].select().where( w ) .to_a

      if( rec.count() != 0 )

        groupByHost = rec.group_by { |k| k[:shortname] }

        return groupByHost
      end

      return Hash.new()

    end


    def setStatus( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      status = params.dig(:status) # Database::ONLINE

      logger.debug( " status( #{params} )")

      w = Array.new

      if( status != nil )

        status = case status
          when Storage::MySQL::ONLINE
            'online'
          when  Storage::MySQL::OFFLINE
            'offline'
          when Storage::MySQL::DELETE
            'delete'
          when Storage::MySQL::PREPARE
            'prepare'
          else
            'unknown'
          end
        w << sprintf( 'status = \'%s\'', status )
      end



      return

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
        Sequel[:short => short.to_s]
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

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)

      logger.debug( " status( #{params} )")

      statement = sprintf('SELECT ip, name, fqdn, status FROM dns WHERE ip = \'%s\' or name = \'%s\' or fqdn = \'%s\'', ip, name, fqdn )
      result    = @client.query( statement, :as => :hash )

      if( result.count != 0 )

        headers = result.fields # <= that's an array of field names, in order
        result.each(:as => :hash) do |row|
          return row
        end
      end

      return nil
    end


    # -- configurations -------------------------
    #
    def createConfig( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

      logger.debug( " createConfig( #{params} )")

      if( ( key == nil && values == nil ) && data.is_a?( Hash ) )

        data.each do |k,v|

          self.writeConfig( { :ip => ip, :short => name, :fqdn => fqdn, :key => k, :value => v } )
        end
      else

        self.writeConfig( params )
      end

      return nil

#       if( self.checkDatabase() == false )
#         return false
#       end
#
#       dnsIp        = params.dig(:ip)
#       dnsShortname = params.dig(:short)
#       dnsChecksum  = params.dig(:checksum)
#       configKey    = params.dig(:key)
#       configValues = params.dig(:value)
#       data         = params.dig(:data)
#
#       if( ( configKey == nil && configValues == nil ) && data.is_a?( Hash ) )
#
#         data.each do |k,v|
#
#           self.writeConfig( { :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :key => k, :value => v } )
#         end
#       else
#
#         self.writeConfig( params )
#       end

    end

    # PRIVATE
    def writeConfig( params = {} )

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)
      values = params.dig(:value)
      data   = params.dig(:data)

      logger.debug( " writeConfig( #{params} )")


      if( ip == nil )

        dns = self.dnsData( params )

        if( dns != nil )
          ip   = dns.dig('ip')
        else

          return false
        end
      end


        statement = sprintf(
          'select * from config where `key` = \'%s\' and `value` = \'%s\' and dns_ip = \'%s\'',
          key, values, ip
        )

        logger.debug( statement )

        result    = @client.query( statement, :as => :hash )

#         logger.debug( result.class.to_s )
#         logger.debug( result.inspect )
#         logger.debug( result.size )

        if( result.size == 0 )

          statement = sprintf('insert into config ( `key`, `value`, dns_ip ) values ( \'%s\', \'%s\', \'%s\' )', key, values, ip )
          logger.debug( statement  )

          result    = @client.query( statement, :as => :hash )

          logger.debug( result.to_a )
        else

          dbaValues = nil

          result.each do |row|
            dbaValues    = row.dig('value')
          end

          logger.debug( "#{values} vs. #{dbaValues}" )

          if( dbaValues.to_s != values.to_s )

            statement = sprintf('update config set `value` = \'%s\' where dns_ip = \'%s\' and `key` = \'%s\'', values, ip, key )
            logger.debug( statement )

            result    = @client.query( statement, :as => :hash )

            logger.debug( result.to_a )
          end

        return nil




#         rec = @database[:config].where(
#           (
#             ( Sequel[:ip        => dnsIp.to_s] ) |
#             ( Sequel[:short => dnsShortname.to_s] )
#           ) & (
#             ( Sequel[:key   => configKey.to_s] ) &
#             ( Sequel[:value => configValues.to_s] )
#           )
#         ).to_a
#
#         if( rec.count() == 0 )
#
#           if( dnsIp != nil )
#             @database[:config].insert(
#               :ip       => dnsIp.to_s,
#               :key      => configKey.to_s,
#               :value    => configValues.to_s,
#               :created  => DateTime.now()
#             )
#
#           elsif( dnsShortname != nil )
#
#             @database[:config].insert(
#               :short => dnsShortname.to_s,
#               :key       => configKey.to_s,
#               :value     => configValues.to_s,
#               :created   => DateTime.now()
#             )
#           end
#         else
#
#           # prüfen, ob 'value' identisch ist
#           dbaValues    = rec.first[:value]
#           configValues = configValues.to_s
#
#           if( dbaValues != configValues )
#
#             if( dnsIp != nil )
#
#               @database[:config].where(
#                 ( Sequel[:ip  => dnsIp.to_s] ) &
#                 ( Sequel[:key => configKey.to_s] )
#               ).update(
#                 :value      => configValues.to_s,
#                 :created    => DateTime.now()
#               )
#             elsif( dnsShortname != nil )
#
#               @database[:config].where(
#                 ( Sequel[:short => dnsShortname.to_s] ) &
#                 ( Sequel[:key       => configKey.to_s] )
#               ).update(
#                 :value      => configValues.to_s,
#                 :created    => DateTime.now()
#               )
#             end
#           end
#         end
      end
    end


    def removeConfig( params = {} )

      if( ! @client )
        return false
      end

      ip    = params.dig(:ip)
      name  = params.dig(:short)
      fqdn  = params.dig(:fqdn)
      key   = params.dig(:key)

      logger.debug( " removeConfig( #{params} )")

      dns = self.dnsData( params )

      if( dns != nil )

        ip   = dns.dig('ip')
        more = nil

        logger.debug( ip )

        if( key != nil )
          more = sprintf( 'and `key` = \'%s\'', key )
        end

        statement = sprintf('DELETE FROM config WHERE dns_ip = \'%s\' %s', ip, more )
        logger.debug( statement )

        begin
          result    = @client.query( statement, :as => :hash )
          return true
        rescue => e
          logger.error( e)
          return false
        end

      end

      return nil
#
#       ip        = params[ :ip ]    ? params[ :ip ]    : nil
#       short     = params[ :short ] ? params[ :short ] : nil
#       long      = params[ :long ]  ? params[ :long ]  : nil
#       configKey = params[ :key ]   ? params[ :key ]   : nil
#
#       rec = @database[:config].select(:shortname).where(
#         ( Sequel[:ip        => ip.to_s] ) |
#         ( Sequel[:short => short.to_s] ) |
#         ( Sequel[:longname  => long.to_s] )
#       ).to_a
#
#       if( rec.count() != 0 )
#
#         shortname = rec.first[:shortname]
#
#         if( configKey == nil )
#
#           @database[:config].where( Sequel[:short => shortname] ).delete
#         else
#           @database[:config].where(
#             ( Sequel[:shortname   => shortname] ) &
#             ( Sequel[:key  => configKey] )
#           ).delete
#         end
#       end
    end

    def parsedResponse( r )

      return JSON.parse( r )
    rescue JSON::ParserError => e
      return r # do smth

    end


    def config( params = {} )

      if( ! @client )
        return false
      end

      ip     = params.dig(:ip)
      name   = params.dig(:short)
      fqdn   = params.dig(:fqdn)
      key    = params.dig(:key)

#       logger.debug( " config( #{params} )")

      statement = sprintf(
        'select dns.fqdn, config.`key`, config.`value` from dns, config where dns.ip = config.dns_ip'
      )

      if( key != nil )
        statement = sprintf( '%s and `key` = \'%s\'', statement, key )
      end

#       logger.debug( statement )

      r    = @client.query( statement, :as => :hash )

#       logger.debug( r.size )

      if( r.size == 0 )
        return nil
      end

      array   = Array.new
      result  = Hash.new()

      r.each do |row|

#         logger.debug( row )

        fqdn  = row.dig('fqdn')
        key   = row.dig('key')
        value = row.dig('value')

#         logger.debug(fqdn)

        result[fqdn.to_s] ||= {}
        result[fqdn.to_s][key.to_s] ||= self.parsedResponse( value )

      end

#       logger.debug( result )

      return result


  #       return nil
#
#
#
#       if( self.checkDatabase() == false )
#         return false
#       end
#
#       ip        = params[ :ip ]    ? params[ :ip ]    : nil
#       short     = params[ :short ] ? params[ :short ] : nil
#       long      = params[ :long ]  ? params[ :long ]  : nil
#       configKey = params[ :key ]   ? params[ :key ]   : nil
#
#       array     = Array.new()
#       result    = Hash.new()
#
#       def dbaData( w )
#
#         return  @database[:v_config].select( :ip, :shortname, :checksum, :key, :value ).where( w ).to_a
#
#       end
#
#       if( configKey == nil )
#
#         w = (
#           ( Sequel[:ip        => ip.to_s] ) |
#           ( Sequel[:short => short.to_s] ) |
#           ( Sequel[:longname  => long.to_s] )
#         )
#
#       else
#
#         w = (
#           ( Sequel[:ip        => ip.to_s] ) |
#           ( Sequel[:short => short.to_s] ) |
#           ( Sequel[:longname  => long.to_s] )
#         ) & (
#           ( Sequel[:key => configKey.to_s] )
#         )
#
#       end
#
#       def collectValues( hashes )
#
#         {}.tap{ |r| hashes.each{ |h| h.each{ |k,v| ( r[k]||=[] ) << v } } }
#       end
#
#       rec = self.dbaData( w )
#
#       if( rec.count() != 0 )
#
#         dnsShortName  = rec.first.dig( :checksum ).to_s
#
#         result[dnsShortName.to_s] ||= {}
#         result[dnsShortName.to_s]['dns'] ||= {}
#         result[dnsShortName.to_s]['dns']['ip']        = rec.first.dig( :ip ).to_s
#         result[dnsShortName.to_s]['dns']['shortname'] = rec.first.dig( :shortname ).to_s
#
#         groupByKey = rec.group_by { |k| k[:key] }
#
#         groupByKey.each do |g,v|
#
#           c = collectValues(
#             v.map do |hash|
#               { value:  ( hash[:value] ) }
#             end
#           )
#
#           values = c.select { |h| h['value'] }
#
#           result[dnsShortName.to_s][g.to_s] ||= {}
#           result[dnsShortName.to_s][g.to_s] = values[:value].flatten.sort
#
#           array << result
#         end
#       else
#         return false
#       end
#
#       array = array.reduce( :merge )
#
#       return array

    end
    #
    # -- configurations -------------------------





  end

  class Sqlite

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
            ( Sequel[:short => dnsShortname.to_s] )
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
              :short => dnsShortname.to_s,
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
                ( Sequel[:short => dnsShortname.to_s] ) &
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
        ( Sequel[:short => short.to_s] ) |
        ( Sequel[:longname  => long.to_s] )
      ).to_a

      if( rec.count() != 0 )

        shortname = rec.first[:shortname]

        if( configKey == nil )

          @database[:config].where( Sequel[:short => shortname] ).delete
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
          ( Sequel[:short => short.to_s] ) |
          ( Sequel[:longname  => long.to_s] )
        )

      else

        w = (
          ( Sequel[:ip        => ip.to_s] ) |
          ( Sequel[:short => short.to_s] ) |
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
        :short => short.to_s,
        :longname  => long.to_s
      ).to_a.first

      # insert if data not found
      if( rec == nil )

        insertedId = dns.insert(
          :ip        => ip.to_s,
          :short => short.to_s,
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
        ( Sequel[:short => short.to_s] ) |
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
        (Sequel[:short => short.to_s] ) |
        (Sequel[:longname  => long.to_s] )
      ).to_a

      if( rec.count() == 0 )
        return nil
      else

        return {
          :id        => rec.first[:id].to_i,
          :ip        => rec.first[:ip].to_s,
          :short => rec.first[:shortname].to_s,
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

        w = ( Sequel[:ip => ip.to_s] ) | ( Sequel[:short => short.to_s] )

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

        return array

      elsif( service != nil && host != nil )

        w = (
          (Sequel[:ip => ip.to_s] ) |
          (Sequel[:short => short.to_s] )
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

        w = ( Sequel[:ip => ip.to_s] ) | ( Sequel[:short => short.to_s] )

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
        Sequel[:short => short.to_s]
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
        Sequel[:ip        => ip.to_s] | Sequel[:short => short.to_s]
      ).to_a

      if( rec.count() == 0 )
        return nil
      else

        return {
          :ip        => rec.first[:ip].to_s,
          :short => rec.first[:shortname].to_s,
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