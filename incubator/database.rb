#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'logger'
require 'dm-types'
require 'dm-core'
require 'dm-constraints'
require 'dm-migrations'

require_relative 'database_data'



# -----------------------------------------------------------------------------

module Logging

  def logger
    @logger ||= Logging.logger_for(self.class.name)
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def configure_logger_for(classname)

#      logFile         = '/var/log/monitoring/monitoring.log'
#      file            = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#      file.sync       = true
#      logger          = Logger.new( file, 'weekly', 1024000 )

      logger                 = Logger.new(STDOUT)
      logger.progname        = classname
      logger.level           = Logger::DEBUG
      logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      logger.formatter       = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime( logger.datetime_format )}] #{severity.ljust(5)} : #{progname} - #{msg}\n"
      end

      logger
    end
  end
end

# -----------------------------------------------------------------------------

module Storage

  class File

  end

  class SQLite

    include Logging

#    include Dns
#    include Discovery
#    include Results

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'

      self.prepare
    end


    def prepare()

      DataMapper::Logger.new( $stdout, :debug )
      DataMapper.setup( :default, 'sqlite:///tmp/project.db' )
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize

      DataMapper.auto_upgrade!

    end


    def createDNS( ip, short, long )

      Dns.update_or_create(
        {
          :ip        => ip.to_s,
          :shortname => short.to_s,
          :longname  => long.to_s
        }, {
          :shortname => short.to_s,
          :longname  => long.to_s
        }
      )
    end


    def dnsData( ip, short = nil, long = nil )

      d = Dns.all( :ip => ip ) |
          Dns.all( :shortname => short ) |
          Dns.all( :longname => long )

      if( d.first == nil )
        return nil
      end

      return {
        :id        => d.map( &:id )[0].to_i,
        :ip        => d.map( &:ip )[0].to_s,
        :shortname => d.map( &:shortname )[0].to_s,
        :longname  => d.map( &:longname )[0].to_s,
        :created   => d.map( &:created )[0].to_s,
        :checksum  => d.map( &:checksum )[0].to_s,
      }

    end


    def createDiscovery( dnsId, dnsIp, dnsShortname, dnsChecksum, service, data )

        Discovery.update_or_create(
          {
            :dns_id         => dnsId,
            :dns_ip         => dnsIp,
            :dns_shortname  => dnsShortname,
            :dns_checksum   => dnsChecksum,
            :service        => service
          }, {
            #:shortname  => 'monitoring-16-01',
            #:md5sum     => '958f0d09e4d3039ef096ec27606de3a87ca10c0453c1b23de688314430c7ee36',
            :service    => service,
            :data       => data
          }
        )

    end


    def discoveryData( params = {} ) #ip, short = nil, service )

      logger.debug()
      ip      = params[ :ip ]      ? params[ :ip ]      : nil
      short   = params[ :short ]   ? params[ :short ]   : nil
      service = params[ :service ] ? params[ :service ] : nil

      array     = Array.new()
      result    = Hash.new()

      logger.debug( params )

#       if( service == nil && ( ip == nil || short == nil ) )
#         logger.debug( 'foo' )
#         return nil
#       end

      # { :service => 'springer-cms' }
      if( service != nil && ( ip == nil && short == nil ) )

        result[service.to_sym] ||= {}

        Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :service => service ).each do |data|

          dnsShortName  = data.attribute_get( :dns_shortname )
          dnsIp         = data.attribute_get( :dns_ip ).to_s
          discoveryData = JSON.parse( data.attribute_get( :data ).to_json )

          result[service.to_sym][dnsShortName] ||= {}
          result[service.to_sym][dnsShortName] = {
            :ip   => dnsIp,
            :data => discoveryData
          }

          array << result
        end

        array = array.reduce( :merge )

        return array

      elsif( service == nil && ( ip == nil || short == nil ) )

        if( ip != nil )
          key = ip
        end
        if( short != nil )
          key = short
        end

        result[key.to_sym] ||= {}

        logger.debug( 'service == nil && ( ip == nil || short == nil )' )

        d = Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_ip => ip ) |
            Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_shortname => short )

        logger.debug( d.inspect )

        d.each do |data|

          dnsShortName  = data.attribute_get( :dns_shortname )
          service         = data.attribute_get( :service ).to_s
          discoveryData = JSON.parse( data.attribute_get( :data ).to_json )

          result[key.to_sym][dnsShortName] ||= {}
          result[key.to_sym][dnsShortName] = {
            :service   => service,
            :data => discoveryData
          }

          array << result
        end

        array = array.reduce( :merge )

        return array

      # { :ip => '10.2.14.156', :service => 'springer-cms' }
      elsif( service != nil && ( ip == nil || short == nil ) )

        d = ( Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_ip => ip ) |
              Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_shortname => short ) ) &
             Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :service => service )

        logger.debug( d.inspect )

        if( d == nil )
          return nil
        end

        data = d.map( &:data )[0].to_json

        return {
          :ip        => d.map( &:dns_ip )[0].to_s,
          :shortname => d.map( &:dns_shortname )[0].to_s,
          :service   => d.map( &:service )[0].to_s,
          :data      => JSON.parse( data )
        }

      end

#       logger.debug( d.inspect )




#
#       d = ( Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_ip => ip ) |
#             Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_shortname => short ) ) &
#           Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :service => service )

#       if( d == nil )
#         return nil
#       end
#
#       data = d.map( &:data )[0].to_json
#
#       return {
#         :ip        => d.map( &:dns_ip )[0].to_s,
#         :shortname => d.map( &:dns_shortname )[0].to_s,
#         :service   => d.map( &:service )[0].to_s,
#         :data      => JSON.parse( data )
#       }



      logger.debug( JSON.pretty_generate( array ) )
      logger.debug()
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

      self.createDNS( '10.2.14.156', 'monitoring-16-01', 'monitoring-16-01.coremedia.vm' )
      self.createDNS( '10.2.14.160', 'monitoring-16-02', 'monitoring-16-02.coremedia.vm' )

      dns = Hash.new()

      ['10.2.14.165', '10.2.14.160', '10.2.14.156' ].each do |i|

        dns = self.dnsData( i )

        if( dns == nil )
          logger.debug( 'no data for ip ' + i )
        else
          dnsId        = dns[ :id ]
          dnsIp        = dns[ :ip ]
          dnsShortname = dns[ :shortname ]
          dnsLongname  = dns[ :longname ]
          dnsCreated   = dns[ :created ]
          dnsChecksum  = dns[ :checksum ]

          data.each do |d|

            service = d.keys[0].to_s

            logger.debug( sprintf( '%s - %s', dnsShortname, service ) )
#             data    = d.values

            self.createDiscovery( dnsId, dnsIp, dnsShortname, dnsChecksum, service, d.values )

          end
        end
      end
    end

    def readData(  )

#       #
#       # puts ""
#       # puts " OR"
#       # # OR
#       # d = Dns.all( :fields=>[:ip, :shortname], :ip => '10.2.14.156' ) | Dns.all(  :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' )
#       # puts d.inspect
#       # puts d.map( &:ip )
#       # puts d.map( &:shortname )
#
#       puts ""
#       puts " AND"
#       # AND
#       d = Dns.all(  :fields=>[:ip, :shortname, :checksum], :ip => '10.2.14.156' ) &
#       Dns.all(  :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' )
#
#       puts d.inspect
#       puts d.map( &:ip )
#       puts d.map( &:shortname )
#
#       d = Discovery.all( :fields => [ :service, :data ], :dns_shortname => 'monitoring-16-01' )
#
#       puts d.inspect
#       puts d.map( &:service )
#       puts d.map( &:data )
#       # puts d.map( &:shortname )



      d = self.discoveryData( { :ip => '10.2.14.156' } ) # { :ip => '10.2.14.156', :short => 'monitoring-16-01' } )

        if( d == nil )
          logger.debug( 'no discovery data found ' )
        else

          logger.debug( d )
#           dnsIp        = d[ :ip ]
#           dnsShortname = d[ :shortname ]
#           service      = d[ :service ]
#           data         = d[ :data ]
#
#           puts d

        end



      # puts ""
      # puts " NOT"
      # # NOT
      # d = Dns.all(  :fields=>[:ip, :shortname], :ip => '10.2.14.156' ) - Dns.all( :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' )
      # puts d.inspect
      # puts d.map( &:ip )
      # puts d.map( &:shortname )
      #
      # d = Dns.all(  :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' ) & Discovery.all( :fields=>[ :data], :shortname => 'monitoring-16-01' )
      # puts d.inspect

    end
  end
#
#       class Dns
#         include DataMapper::Resource
#
#         property :id          , Serial
#         property :ip          , IPAddress, :required => true, :key => true
#         property :shortname   , String   , :required => true, :key => true, :length => 60
#         property :longname    , String   , :required => true,               :length => 250
#         property :md5sum      , String   , :length => 64    , :key => true, :default => lambda { |r, p| Digest::SHA256.hexdigest( r.shortname ) }
#       end
#
#       class Discovery
#         include DataMapper::Resource
#
#         property :id          , Serial
#         property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
#         property :shortname   , String   , :required => true, :length => 60
#         property :md5sum      , String   , :required => true, :length => 64, :key => true
#         property :data        , Json     , :required => true
#
#
#         property :status      , Flag[ :online, :offline ], :default => :offline
#
#       end
#
#       class Results
#         include DataMapper::Resource
#
#         property :id          , Serial
#         property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
#         property :service     , String   , :required => true, :length => 60
#         property :md5sum      , String   , :required => true, :length => 64, :key => true
#         property :data        , Json     , :required => true
#       end


end


m = Storage::SQLite.new()

m.insertData()
m.readData()



#if( DataMapper.repository(:default).adapter.storage_exists?('dns') && DataMapper.repository(:default).adapter.storage_exists?('node') )
#  DataMapper.auto_migrate!
#end


#dns  = Dns.new()
#node = Node.new()


