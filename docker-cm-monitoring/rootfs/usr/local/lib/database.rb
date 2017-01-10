#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'logger'
require 'sequel'
require 'digest/md5'

require_relative 'logging'
require_relative 'tools'

# -----------------------------------------------------------------------------

module StorageOld

  class File

  end

  class Database

    include Logging

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'

      self.prepare
    end


    def prepare()

      @database = Sequel.sqlite( sprintf( '%s/monitoring.db', @cacheDirectory ) )
      @database.loggers << logger # Logger.new( $stdout, :debug )

      @database.create_table?( :dns ) {
        primary_key :id
        String      :ip        , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :shortname , :size => 60 , :key => true, :index => true, :unique => true, :null => false
        String      :longname  , :size => 250
        DateTime    :created   , :default => Time.now
        String      :checksum  , :size => 32
        FalseClass  :status
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

      @database.create_table?( :discovery ) {
        primary_key :id
        foreign_key :dns_id, :dns
        String      :service   , :size => 128 , :key => true, :index => true, :null => false
        Integer     :port      , :null => false
        String      :data      , :text => true, :null => false
        DateTime    :created   , :default => Time.now()

        index [ :dns_id, :service, :port ]
#        foreign_key [:shortname, :service], :name => 'unique_discovery'
      }

      @database.create_table?( :result ) {
        primary_key :id
        foreign_key :dns_id, :dns
        foreign_key :discovery_id, :discovery
        String      :service   , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :data      , :text => true, :null => false
        DateTime    :created   , :default => Time.now()

        index [:dns_id, :discovery_id, :service ]
#         foreign_key [:shortname], :dns
#         foreign_key [:service]  , :discovery
      }

      @database.create_or_replace_view( :v_discovery,
        'select dns.ip, dns.shortname, dns.created, discovery.* from dns as dns, discovery as discovery where dns.id = discovery.dns_id' )

      @database.create_or_replace_view( :v_config,
        'select
          dns.ip, dns.shortname, dns.longname, dns.checksum,
          config.id, config.key, config.value
        from
          dns as dns, config as config
        order by key'
      )


    end


    # -- configurations -------------------------
    #
    def createConfig( params = {} )

      dnsIp        = params[ :ip ]       ? params[ :ip ]       : nil
      dnsShortname = params[ :short ]    ? params[ :short ]    : nil
      dnsChecksum  = params[ :checksum ] ? params[ :checksum ] : nil
      configKey    = params[ :key ]      ? params[ :key ]      : nil
      configValues = params[ :value ]    ? params[ :value ]    : nil
      data         = params[ :data ]     ? params[ :data ]     : nil

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

      dnsIp        = params[ :ip ]       ? params[ :ip ]       : nil
      dnsShortname = params[ :short ]    ? params[ :short ]    : nil
      dnsChecksum  = params[ :checksum ] ? params[ :checksum ] : nil
      configKey    = params[ :key ]      ? params[ :key ]      : nil
      configValues = params[ :value ]    ? params[ :value ]    : nil

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

      def parsedResponse( r )
        return JSON.parse( r )
      rescue JSON::ParserError => e
        return r # do smth
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



    def createDNS( params = {} )

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil

      dns = @database[:dns]

      rec = dns.select(:id).where(
        :ip        => ip.to_s,
        :shortname => short.to_s,
        :longname  => long.to_s
      ).to_a.first

      # insert if data not found
      if( rec == nil )

        dns.insert(
          :ip        => ip.to_s,
          :shortname => short.to_s,
          :longname  => long.to_s,
          :checksum  => Digest::MD5.hexdigest( [ ip, short, long ].join ),
          :created   => DateTime.now(),
          :status    => isRunning?( long )
        )
      end

    end


    def removeDNS( params = {} )

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

        @database[:result].where( Sequel[:dns_id => id] ).delete
        @database[:discovery].where( Sequel[:dns_id => id] ).delete
        @database[:dns].where( Sequel[:id => id] ).delete

      end

    end


    def dnsData( params = {}  )

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


    def createDiscovery( params = {} )

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
          logger.debug( sprintf( '%s - %s - %s', dnsShortname, p, k ) )

          self.writeDiscovery( { :id => dnsId, :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :port => p, :service => k, :data => v } )

        end

      else
        self.writeDiscovery( params )
      end

    end

    # PRIVATE
    def writeDiscovery( params = {} )

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

      logger.debug()
      logger.debug( params )

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

        return  @database[:v_discovery].select( :ip, :shortname, :created, :service, :data ).where( w ).to_a

      end


      # ---------------------------------------------------------------------------------

      if( service == nil && host == nil )

        logger.error( '( service == nil && host == nil )' )

        rec = self.dbaData( nil )

        groupByHost = rec.group_by { |k| k[:shortname] }

        return groupByHost.keys

      #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
      elsif( service != nil && host == nil )

        logger.debug( '( service != nil && host == nil )' )
        w = ( Sequel[:service => service.to_s] )

        rec = self.dbaData( w )

        result[service.to_s] ||= {}

        rec.each do |data|

          dnsShortName  = data.dig( :shortname ).to_s
          service       = data.dig( :service ).to_s
          discoveryData = data.dig( :data )

          result[service.to_s][dnsShortName] ||= {}
          result[service.to_s][dnsShortName] = {
            :data => JSON.parse( discoveryData )
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
          discoveryData = data.dig( :data )

          result[host.to_s][service] ||= {}
          result[host.to_s][service] = {
            :data => JSON.parse( discoveryData )
          }

          array << result
        end

        array = array.reduce( :merge )

        logger.debug( JSON.pretty_generate( array ) )

        return array

      elsif( service != nil && host != nil )

        logger.debug( '( service != nil && host != nil )' )
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

          discoveryData  = rec.first[:data] # d.map( &:data )[0].to_json

          result[host.to_s][service] ||= {}
          result[host.to_s][service] = {
            :data => JSON.parse( discoveryData )
          }

          array << result
          array = array.reduce( :merge )

          return array
        end

      end

      return nil

    end


    def insertData()

      data = Array.new()

      data << {
        "replication-live-server"=> {
        "port"=> 48099,
        "description"=> "RLS",
        "port_http"=> 48080,
        "ior"=> true,
        "runlevel"=> true,
        "license"=> true,
        "application"=> [
           "contentserver"
          ]
        }
      }

      data << {
        "springer-cms"=> {
          "port"=> 49099,
          "description"=> "CAE Live 1",
          "cap_connection"=> true,
          "uapi_cache"=> true,
          "blob_cache"=> true,
          "application"=> [
             "cae",
             "caches"
            ]
        }
      }

      # puts JSON.pretty_generate( data )

      self.createDNS( { :ip => '10.2.14.156', :short => 'monitoring-16-01', :long => 'monitoring-16-01.coremedia.vm' } )
      self.createDNS( { :ip => '10.2.14.160', :short => 'monitoring-16-02', :long => 'monitoring-16-02.coremedia.vm' } )

      dns = Hash.new()

      [ 'monitoring-16-01', 'monitoring-16-02', 'foo' ].each do |i|

        dns = self.dnsData( { :short => i } )

        if( dns == nil )
          logger.debug( 'no data for ' + i )
        else
          dnsId        = dns[ :id ]
          dnsIp        = dns[ :ip ]
          dnsShortname = dns[ :shortname ]
          dnsLongname  = dns[ :longname ]
          dnsCreated   = dns[ :created ]
          dnsChecksum  = dns[ :checksum ]

          logger.debug( JSON.pretty_generate dns )

          data.each do |d|

            service = d.keys[0].to_s

            logger.debug( sprintf( '%s - %s', dnsShortname, service ) )
#             data    = d.values

            self.createDiscovery( { :id => dnsId, :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :service => service, :data => d.values } )

          end
        end
      end
    end


    def readData(  )

      d = self.discoveryData( { :ip => '10.2.14.156' } )
      logger.debug( JSON.pretty_generate( d ) )
      logger.debug( '===' )
      d = self.discoveryData( { :short => 'monitoring-16-01' } )
      logger.debug( JSON.pretty_generate( d ) )
      logger.debug( '===' )
      d = self.discoveryData( { :short => 'monitoring-16-01', :service => 'replication-live-server' } )
      logger.debug( JSON.pretty_generate( d ) )
      logger.debug( '===' )
      d = self.discoveryData( { :service => 'replication-live-server' } )
      logger.debug( JSON.pretty_generate( d ) )
      logger.debug( '===' )


    end


  end


end

# ---------------------------------------------------------------------------------------

# TESTS
#m = Storage::SQLite.new()
#
# m.insertData()
#m.readData()

