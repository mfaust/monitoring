#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'logger'
require 'sequel'
require 'digest/md5'

require_relative 'logging'
require_relative 'tools'

# -----------------------------------------------------------------------------

module Storage

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
      @database.loggers << Logger.new( $stdout, :debug )

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
        foreign_key :dns_id, :dns
        String      :service   , :size => 128 , :key => true, :index => true, :unique => true, :null => false
        String      :data      , :text => true, :null => false
        DateTime    :created   , :default => Time.now()

        index [:dns_id, :service ]
      }

      @database.create_table?( :discovery ) {
        primary_key :id
        foreign_key :dns_id, :dns
        String      :service   , :size => 128, :key => true, :index => true, :null => false
        String      :data      , :text => true, :null => false
        DateTime    :created   , :default => Time.now()

        index [:dns_id, :service ]
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
        'select dns.ip, dns.shortname, discovery.* from dns as dns, discovery as discovery where dns.id = discovery.dns_id' )


    end


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

        @database[:result].where( Sequel[:dns_id => id.to_i] ).delete
        @database[:discovery].where( Sequel[:dns_id => id.to_i] ).delete
        @database[:dns].where( Sequel[:id => id.to_i] ).delete

      end

    end



    def dnsData( params = {}  )

      ip      = params[ :ip ]    ? params[ :ip ]    : nil
      short   = params[ :short ] ? params[ :short ] : nil
      long    = params[ :long ]  ? params[ :long ]  : nil

      dns = @database[:dns]

      rec = dns.where(
        (Sequel[:ip => ip.to_s] ) |
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
      service      = params[ :service ]  ? params[ :service ]  : nil
      data         = params[ :data ]     ? params[ :data ]     : nil

      if( service == nil && data.is_a?( Hash ) )

        data.each do |k,v|

          logger.debug( sprintf( '%s - %s', dnsShortname, k ) )

          self.writeDiscovery( { :id => dnsId, :ip => dnsIp, :short => dnsShortname, :checksum => dnsChecksum, :service => k, :data => v } )

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

        return  @database[:v_discovery].select( :ip, :shortname, :service, :data ).where( w ).to_a

      end


      # ---------------------------------------------------------------------------------

      if( service == nil && host == nil )

        logger.error( 'no data' )

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

