#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'logger'
require 'sequel'
require 'digest/md5'

require_relative '../docker-cm-monitoring/rootfs/usr/local/lib/tools'

# require 'dm-types'
# require 'dm-core'
# require 'dm-constraints'
# require 'dm-migrations'

# require_relative 'database_data'



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

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'

      self.prepare
    end


    def prepare()

      @database = Sequel.sqlite( '/tmp/project.db' )
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
        DateTime    :created   , :default => 'now()'
        String      :shortname , :size => 60 , :key => true, :index => true, :unique => true, :null => false
        String      :service   , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :data      , :text => true, :null => false
      }

      @database.create_table?( :discovery ) {
        primary_key :id
        DateTime    :created   , :default => 'now()'
        String      :shortname , :size => 60 , :key => true, :index => true, :unique => true, :null => false
        String      :service   , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :data      , :text => true, :null => false
      }

      @database.create_table?( :result ) {
        primary_key :id
        DateTime    :created   , :default => 'now()'
        String      :shortname , :size => 60 , :key => true, :index => true, :unique => true, :null => false
        String      :service   , :size => 128, :key => true, :index => true, :unique => true, :null => false
        String      :data      , :text => true, :null => false
      }

#      DataMapper::Logger.new( $stdout, :info )
#      DataMapper.setup( :default, 'sqlite:///tmp/project.db' )
#      DataMapper::Model.raise_on_save_failure = true
#      DataMapper.finalize
#
#      DataMapper.auto_upgrade!

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
          :checksum  => Digest::MD5.hexdigest( [ :ip, :shortname, :longname ].join ),
          :created   => DateTime.now(),
          :status    => isRunning?( long )
        )
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


#     def createDiscovery( params = {} ) #  dnsId, dnsIp, dnsShortname, dnsChecksum, service, data )
#
#       dnsId        = params[ :id ]       ? params[ :id ]       : nil
#       dnsIp        = params[ :ip ]       ? params[ :ip ]       : nil
#       dnsShortname = params[ :short ]    ? params[ :short ]    : nil
#       dnsChecksum  = params[ :checksum ] ? params[ :checksum ] : nil
#       service      = params[ :service ]  ? params[ :service ]  : nil
#       data         = params[ :data ]     ? params[ :data ]     : nil
#
#       Discovery.update_or_create(
#         {
#           :dns_id         => dnsId,
#           :dns_ip         => dnsIp,
#           :dns_shortname  => dnsShortname,
#           :dns_checksum   => dnsChecksum,
#           :service        => service
#         }, {
#           :service    => service,
#           :data       => data
#         }
#       )
#
#     end
#
#
#     def discoveryData( params = {} ) #ip, short = nil, service )
#
#       logger.debug()
#       logger.debug( params )
#
#       ip      = params[ :ip ]      ? params[ :ip ]      : nil
#       short   = params[ :short ]   ? params[ :short ]   : nil
#       service = params[ :service ] ? params[ :service ] : nil
#
#       array     = Array.new()
#       result    = Hash.new()
#
#       if( ( ip != nil || short != nil ) )
#
#         if( ip != nil )
#           host = ip
#         end
#         if( short != nil )
#           host = short
#         end
#       else
#         host = nil
#       end
#
#       # ---------------------------------------------------------------------------------
#
#       if( service == nil && host == nil )
#
#         logger.error( 'no data' )
#
#       #  { :short => 'monitoring-16-01', :service => 'replication-live-server' }
#       elsif( service != nil && host == nil )
#
#         result[service.to_s] ||= {}
#
#         Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :service => service ).each do |data|
#
#           dnsShortName  = data.attribute_get( :dns_shortname )
#           dnsIp         = data.attribute_get( :dns_ip ).to_s
#           discoveryData = JSON.parse( data.attribute_get( :data ).to_json )
#
#           result[service.to_s][dnsShortName] ||= {}
#           result[service.to_s][dnsShortName] = {
#             :ip   => dnsIp,
#             :data => discoveryData
#           }
#
#           array << result
#         end
#
#         array = array.reduce( :merge )
#
#         return array
#
#       # { :short => 'monitoring-16-01' }
#       elsif( service == nil && host != nil )
#
#         d = Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_ip => ip ) |
#             Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_shortname => short )
#
#         result[host.to_s] ||= {}
#
#         d.each do |data|
#
#           dnsShortName  = data.attribute_get( :dns_shortname ).to_s
#           service       = data.attribute_get( :service ).to_s
#           discoveryData = JSON.parse( data.attribute_get( :data ).to_json )
#
#           result[host.to_s][service] ||= {}
#           result[host.to_s][service] = {
#             :data => discoveryData
#           }
#
#           array << result
#         end
#
#         array = array.reduce( :merge )
#
#         return array
#
#       elsif( service != nil && host != nil )
#
#         d = ( Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_ip => ip ) |
#               Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :dns_shortname => short ) ) &
#              Discovery.all( :fields=>[ :dns_ip, :dns_shortname, :service, :data ], :service => service )
#
#         if( d == nil )
#           return nil
#         end
#
#         result[host.to_s] ||= {}
#
#         service        = d.map( &:service )[0].to_s
#         discoveryData  = d.map( &:data )[0].to_json
#
#         result[host.to_s][service] ||= {}
#         result[host.to_s][service] = {
#           :data => JSON.parse( discoveryData )
#         }
#
#         array << result
#         array = array.reduce( :merge )
#
#         return array
#
# #        logger.debug( JSON.pretty_generate( array ) )
#       else
#         logger.error( 'no matches' )
#       end
#
#
#       return nil
#
#     end
#
#
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
      self.createDNS( { :ip => '10.2.14.165', :short => 'monitoring-16-07', :long => 'monitoring-16-07.coremedia.vm' } )


      dns = Hash.new()

      [ 'monitoring-16-01', 'monitoring-16-02', 'foo' ].each do |i|

        dns = self.dnsData( { :short => i } )

        logger.debug( dns )

        next

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
#
#     def readData(  )
#
#       d = self.discoveryData( { :ip => '10.2.14.156' } )
#       logger.debug( JSON.pretty_generate( d ) )
#       logger.debug( '===' )
#       d = self.discoveryData( { :short => 'monitoring-16-01' } )
#       logger.debug( JSON.pretty_generate( d ) )
#       logger.debug( '===' )
#       d = self.discoveryData( { :short => 'monitoring-16-01', :service => 'replication-live-server' } )
#       logger.debug( JSON.pretty_generate( d ) )
#       logger.debug( '===' )
#       d = self.discoveryData( { :service => 'replication-live-server' } )
#       logger.debug( JSON.pretty_generate( d ) )
#       logger.debug( '===' )
#
#
#     end
  end


end

# ---------------------------------------------------------------------------------------

# TESTS
m = Storage::SQLite.new()

m.insertData()
#m.readData()

