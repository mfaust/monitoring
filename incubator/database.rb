#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'logger'
require 'dm-types'
require 'dm-core'
require 'dm-constraints'
require 'dm-migrations'

require_relative 'database_data'


module DataMapper
  module Model
    def update_or_create(conditions = {}, attributes = {}, merger = true)
      (first(conditions) && first(conditions).update(attributes)) || create(merger ? (conditions.merge(attributes)) : attributes )
    end
  end # Module Model
end # Module DataMapper



module Storage

  class File

  end

  class SQLite

#    include Dns
#    include Discovery
#    include Results

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'
      @logDirectory      = params[:logDirectory]   ? params[:logDirectory]   : '/var/log/monitoring'

      @log = Logger.new( STDOUT )
      @log.level     = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime( @log.datetime_format )}] #{severity.ljust(5)} : #{progname} - #{msg}\n"
      end

      self.prepare
    end


    def prepare()

      DataMapper::Logger.new( $stdout, :debug )
      DataMapper.setup( :default, 'sqlite:///tmp/project.db' )
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize

      DataMapper.auto_upgrade!

    end

    def insertData()


      data  = {
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
        },
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

      Dns.update_or_create( {
                             :ip        => '10.2.14.156',
                             :shortname => 'monitoring-16-01',
                             :longname  => 'monitoring-16-01.coremedia.vm'
                            }, {
                                :shortname => 'monitoring-16-01',
                                :longname  => 'monitoring-16-01.coremedia.vm'
                               }
                          )

      Discovery.update_or_create( {
                                   :dns_id     => 1,
                                   :dns_ip     => '10.2.14.156',
                                   :dns_shortname  => 'monitoring-16-01',
                                   :dns_checksum   => '958f0d09e4d3039ef096ec27606de3a87ca10c0453c1b23de688314430c7ee36'
                                  }, {
                                      #     :shortname  => 'monitoring-16-01',
                                      #     :md5sum     => '958f0d09e4d3039ef096ec27606de3a87ca10c0453c1b23de688314430c7ee36',
                                      :data       => data
                                     }
                                )


    end

    def readData()

      #
      # puts ""
      # puts " OR"
      # # OR
      # d = Dns.all( :fields=>[:ip, :shortname], :ip => '10.2.14.156' ) | Dns.all(  :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' )
      # puts d.inspect
      # puts d.map( &:ip )
      # puts d.map( &:shortname )

      puts ""
      puts " AND"
      # AND
      d = Dns.all(  :fields=>[:ip, :shortname, :checksum], :ip => '10.2.14.156' ) &
      Dns.all(  :fields=>[:ip, :shortname], :shortname => 'monitoring-16-01' )

      puts d.inspect
      puts d.map( &:ip )
      puts d.map( &:shortname )

      d = Discovery.all( :fields => [ :data ], :dns_shortname => 'monitoring-16-01' )

      puts d.inspect
      puts d.map( &:data)
      # puts d.map( &:shortname )


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


