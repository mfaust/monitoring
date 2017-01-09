#!/usr/bin/ruby
#
# 07.01.2017 - Bodo Schulz
#
#
# v1.5.0

# -----------------------------------------------------------------------------
require 'json'
# require 'uri'
require 'socket'
require 'timeout'
require 'dalli'
require 'fileutils'
require 'time'
require 'date'
require 'time_difference'

require_relative 'logging'
require_relative 'jolokia'
require_relative 'message-queue'
require_relative 'storage'
require_relative 'external-clients'

# -----------------------------------------------------------------------------

module DataCollector

  class Config

    include Logging

    attr_accessor :config
    attr_accessor :jolokiaApplications

    @@jolokiaApplications = 'initial value'

    def initialize( params = {} )

      applicationConfig   = params[:applicationConfigFile] ? params[:applicationConfigFile] : nil
      serviceConfig       = params[:serviceConfigFile]     ? params[:serviceConfigFile]     : nil

      @config             = nil
      jolokiaApplications = nil

      appConfigFile  = File.expand_path( applicationConfig )

      begin

        if( File.exist?( appConfigFile ) )

          @config      = YAML.load_file( appConfigFile )

          @jolokiaApplications = @config.dig( 'jolokia', 'applications' )

        else
          logger.error( sprintf( 'Application Config File %s not found!', appConfigFile ) )
          exit 1
        end
      rescue => e

      end

    end

  end


  class Prepare

    include Logging

    def initialize( settings = {} )

      applicationConfig  = settings[:applicationConfigFile] ? settings[:applicationConfigFile] : nil
      serviceConfig      = settings[:serviceConfigFile]     ? settings[:serviceConfigFile]     : nil

      @host              = settings[:host]                  ? settings[:host]                  : nil

      @db                = Storage::Database.new()

      @cfg = Config.new( settings )

    end


    def mergeSolrCores( metrics, cores = [] )

      work = Array.new()

      cores.each do |core|

        metric = Marshal.load( Marshal.dump( metrics ) )

        metric.each do |m|
          mb = m['mbean']
          mb.sub!( '%CORE%', core )
        end

        work.push( metric )
      end

      work.flatten!

      return work
    end

    # merge Data between Property Files and discovered Services
    # creates mergedHostData.json for every Node
    def buildMergedData()

      if( @host == nil )
        logger.error( 'no hostname found' )
        return {}
      end

      # Database
      tomcatApplication = Marshal.load( Marshal.dump( @cfg.jolokiaApplications ) )

      data = @db.discoveryData( { :ip => @host, :short => @host } )

      if( data == nil )
        return false
      end

      data.each do |host,d|

        d.each do |service,payload|

#          logger.debug( 'merge Data between discovered Services and Property File' )
#          logger.debug( service )

          dnsId       = payload.dig( :dns_id )
          discoveryId = payload.dig( :discovery_id )

          result      = self.mergeData( service, tomcatApplication, payload )
#           logger.debug( JSON.pretty_generate( result ) )

          @db.createMeasurements( { :dns_id => dnsId, :discovery_id => discoveryId, :data => result } )
        end
      end

      if( data == nil || data == false )
        logger.error( 'no DNS configuration found' )
        return {}
      end

      return true

    end


    def mergeData( service, tomcatApplication, data = {} )

      metricsTomcat     = tomcatApplication['tomcat']      # standard metrics for Tomcat

#      logger.debug( data )

      application = data[:data]['application'] ? data[:data]['application'] : nil
      solr_cores  = data[:data]['cores']       ? data[:data]['cores']       : nil
      metrics     = data[:data]['metrics']     ? data[:data]['metrics']     : nil

      data[:data]['metrics'] = Array.new()

      if( application != nil )

        application.each do |a|

          if( tomcatApplication[a] )

            applicationMetrics = tomcatApplication[a]['metrics']

#             logger.debug( "  add application metrics for #{a}" )

            if( solr_cores != nil )
              data[:data]['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
            end

            # remove unneeded Templates
            tomcatApplication[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

            data[:data]['metrics'].push( metricsTomcat['metrics'] )
            data[:data]['metrics'].push( applicationMetrics )

          end
        end

      end

      if( tomcatApplication[service] )

#         logger.debug( "found #{service} in tomcat application" )

        data[:data]['metrics'].push( metricsTomcat['metrics'] )
        data[:data]['metrics'].push( tomcatApplication[service]['metrics'] )
      end

      data[:data]['metrics'].compact!   # remove 'nil' from array
      data[:data]['metrics'].flatten!   # clean up and reduce depth

      return data[:data]
    end

  end


  class Collector

    include Logging

    def initialize( settings = {} )

      @logDirectory       = settings[:logDirectory]          ? settings[:logDirectory]          : '/var/log/monitoring'
      @cacheDirectory     = settings[:cacheDirectory]        ? settings[:cacheDirectory]        : '/var/cache/monitoring'
      @jolokiaHost        = settings[:jolokiaHost]           ? settings[:jolokiaHost]           : 'localhost'
      @jolokiaPort        = settings[:jolokiaPort]           ? settings[:jolokiaPort]           : 8080
      @memcacheHost       = settings[:memcacheHost]          ? settings[:memcacheHost]          : 'loclahost'
      @memcachePort       = settings[:memcachePort]          ? settings[:memcachePort]          : 11211
      @mqHost             = settings[:mqHost]                ? settings[:mqHost]                : 'localhost'
      @mqPort             = settings[:mqPort]                ? settings[:mqPort]                : 11300
      @mqQueue            = settings[:mqQueue]               ? settings[:mqQueue]               : 'mq-collector'

      @applicationConfig  = settings[:applicationConfigFile] ? settings[:applicationConfigFile] : nil
      @serviceConfig      = settings[:serviceConfigFile]     ? settings[:serviceConfigFile]     : nil

      @db                 = Storage::Database.new()
      @mc                 = Storage::Memcached.new( { :host => @memcacheHost, :port => @memcachePort } )
      @jolokia            = Jolokia::Client.new( { :host => @jolokiaHost, :port => @jolokiaPort } )

      @MQSettings = {
        :beanstalkHost => @mqHost,
        :beanstalkPort => @mqPort
      }

      if( @applicationConfig == nil || @serviceConfig == nil )
        msg = 'no Configuration File given'
        logger.error( msg )

        exit 1
      end

      version            = '1.5.0'
      date               = '2017-01-07'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - DataCollector' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016 Coremedia' )
      logger.info( "  cache directory located at #{@cacheDirectory}" )
      logger.info( "  Memcache Service #{@memcacheHost}:#{@memcachePort}" )
      logger.info( "  Message Queue Service #{@mqHost}:#{@mqPort}/#{@mqQueue}" )
      logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

    end


    def mongoDBData( host, data = {} )

      m = ExternalClients::MongoDb.new( { :host => host, :port => 28017 } )

      return m.get()

  end

    def mysqlData( host, data = {} )

      user = data['user'] ? data['user'] : 'cm_management'
      pass = data['pass'] ? data['pass'] : 'cm_management'
      port = data['port'] ? data['port'] : 3306

      if( port != nil )

        # TODO
        # we need an low-level-priv User for Monitoring!
        settings = {
          :host     => host,
          :username => user,
          :password => pass
        }
      end

      m = ExternalClients::MySQL.new( { :host => host, :username => user, :password => pass } )
      mysqlData = m.get()

      if( mysqlData == false )
        mysqlData   = JSON.generate( { :status => 500 } )
      end

      data           = JSON.parse( mysqlData )

      return data

    end

    def nodeExporterData( host, data = {} )

      port = data[:port] ? data[:port] : 9100

      if( port != nil )

        m = ExternalClients::NodeExporter.new( { :host => host, :port => port } )
        nodeData = m.get()

        result   = JSON.generate( nodeData )
        data     = JSON.parse( result )

        return data
      end

    end


    # return all known and active (online) server for monitoring
    #
    def monitoredServer()

      d = @db.nodes( { :status => 1 } )

#       logger.debug( d )

      return d

    end

    # create a singulary json for every services to send them to the jolokia service
    #
    def createBulkCheck( host )

      checks   = Array.new()
      array    = Array.new()
      services = nil

      result = {
        :timestamp   => Time.now().to_i
      }

#       logger.debug( sprintf( 'create bulk checks for \'%s\'', host ) )

      data = @db.measurements( { :ip => host, :short => host } )

      if( data == nil || data == false )
        return
      end

      services = data.dig( host )

      if( services == nil )
        logger.error( 'no services found. skip ...' )
        return
      end

      services      = services.keys
      servicesCount = services.count

      logger.debug( sprintf( '%d services found', servicesCount ) )

      services.each do |s|

        port    = data.dig( host, s, :data, 'port' )
        metrics = data.dig( host, s, :data, 'metrics' )
        bulk    = Array.new()

        logger.debug( sprintf( '  %s (%d)', s, port ) )

        if( metrics != nil && metrics.count == 0 )
          case s
          when 'mysql'
            # MySQL
            bulk.push( '' )
          when 'mongodb'
            # MongoDB
            bulk.push( '' )
          when 'node_exporter'
            # Node Exporter (from Prometheus)
            bulk.push( '' )
          when 'postgres'
            # Postgres
          else
            # all others
          end
        else

          metrics.each do |e|

            target = {
              'type'   => 'read',
              'mbean'  => e['mbean'].to_s,
              'target' => { 'url' => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port ) },
              'config' => { 'ignoreErrors' => true, 'ifModifiedSince' => true, 'canonicalNaming' => true }
            }

            attributes = []
            if( e['attribute'] )
              e['attribute'].split(',').each do |t|
                attributes.push( t.to_s )
              end

              target['attribute'] = attributes
            end

            bulk.push( target )
          end
        end

        if( bulk.count != 0 )
          checks.push( { s => bulk.flatten } )
        end

      end

      checks.flatten!

      result[:hostname] = host
      result[:services] = *services
      result[:checks]   = *checks

#       logger.debug( JSON.pretty_generate( result ) )
        # send json to jolokia
      self.sendChecksToJolokia( result )

      checks.clear()
      result.clear()

      return

    end


    # extract Host and Port of destination services from rmi uri
    #  - rmi uri are : "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
    #    host: moebius-16-tomcat
    #    port: 2222
    def checkHostAndService( targetUrl )

      result = false

      regex = /
        ^                   # Starting at the front of the string
        (.*):\/\/           # all after the douple slashes
        (?<host>.+\S)       # our hostname
        :                   # seperator between host and port
        (?<port>\d+)        # our port
      /x

      # prepare
      parts     = targetUrl.match( regex )
      destHost  = parts['host'].to_s.strip
      destPort  = parts['port'].to_s.strip

#       logger.debug( sprintf( 'check Port %s on Host %s for sending data', destPort, destHost ) )

      result = portOpen?( destHost, destPort )

      if( result == false )
        logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', destPort, destHost ) )
      end

      return result

    end


    # send json data to jolokia and save the result in an memory storage (e.g. memcache)
    #
    def sendChecksToJolokia( data )

      if( @jolokia.jolokiaIsAvailable?() == false )

        logger.error( 'jolokia service is not available!' )

        return {
          :status  => 500,
          :message => 'jolokia service is not available!'
        }
      end

      hostname  = data[:hostname] ? data[:hostname] : nil
      checks    = data[:checks]   ? data[:checks]   : nil

      result    = {
        :hostname  => hostname,
        :timestamp => Time.now().to_i
      }

      checks.each do |c|

        c.each do |v,i|

#           logger.debug( sprintf( '%d checks for service %s found', i.count, v ) )

          target = i[0]['target'] ? i[0]['target'] : nil

          if( target == nil )

            case v
            when 'mysql'
              # MySQL
              result[v] = self.mysqlData( hostname )
            when 'mongodb'
              # MongoDB
              result[v] = self.mongoDBData( hostname )
            when 'postgres'
              # Postgres
            when 'node_exporter'
              # node_exporter
              result[v] = self.nodeExporterData( hostname )
            else
              # all others
            end

          else

            targetUrl = target['url']

            if( self.checkHostAndService( targetUrl ) == true )

              response  = @jolokia.post( { :payload => i } )

              result[v] = self.reorganizeData( response[:message] )

            end
          end

          @mc.set( Storage::Memcached.cacheKey( { :host => hostname, :pre => 'result', :service => v } ), result[v] )

        end
      end
    end


    # reorganize data to later simple find
    def reorganizeData( data )

      if( data == nil )
        logger.error( "      no data for reorganize" )
        logger.error( "      skip" )
        return nil
      end

      result  = Array.new()

      data.each do |c|

        mbean      = c['request']['mbean']
        request    = c['request']
        value      = c['value']
        timestamp  = c['timestamp']
        status     = c['status']

        # "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
        regex = /
          ^                   # Starting at the front of the string
          (.*):\/\/           # all after the douple slashes
          (?<host>.+\S)       # our hostname
          :                   # seperator between host and port
          (?<port>\d+)        # our port
        /x

        uri   = request['target']['url']
        parts = uri.match( regex )
        host  = parts['host'].to_s.strip
        port  = parts['port'].to_s.strip


        if( mbean.include?( 'Cache.Classes' ) )
          regex = /
            CacheClass=
            "(?<type>.+[a-zA-Z])"
            /x
          parts           = mbean.match( regex )
          cacheClass      = parts['type'].to_s

          if( cacheClass.include?( 'ecommerce.ibm' ) )
            format   = 'CacheClassesIBM%s'
          else
            format   = 'CacheClasses%s'
          end

          cacheClass     = cacheClass.split('.').last
          cacheClass[0]  = cacheClass[0].to_s.capitalize
          mbean_type     = sprintf( format, cacheClass )


        elsif( mbean.include?( 'module=' ) )
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            module=               #
            (?<module>.+[a-zA-Z]) #
            (.*)                  #
            pool=                 #
            (?<pool>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
          /x

          parts           = mbean.match( regex )
          mbeanModule     = parts['module'].to_s.strip.tr( '. ', '' )
          mbeanPool       = parts['pool'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanPool )

        elsif( mbean.include?( 'bean=' ) )

          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            bean=                 #
            (?<bean>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanBean       = parts['bean'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanBean )

        elsif( mbean.include?( 'name=' ) )
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            name=                 #
            (?<name>.+[a-zA-Z])   #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanName       = parts['name'].to_s.strip.tr( '. ', '' )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s%s', mbeanType, mbeanName )

        elsif( mbean.include?( 'solr') )

          regex = /
            ^                     # Starting at the front of the string
            solr\/                #
            (?<core>.+[a-zA-Z0-9]):  #
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanCore       = parts['core'].to_s.strip.tr( '. ', '' )
          mbeanCore[0]    = mbeanCore[0].to_s.capitalize
          mbeanType       = parts['type'].to_s.tr( '. /', '' )
          mbeanType[0]    = mbeanType[0].to_s.capitalize
          mbean_type      = sprintf( 'Solr%s%s', mbeanCore, mbeanType )

        else
          regex = /
            ^                     # Starting at the front of the string
            (.*)                  #
            type=                 #
            (?<type>.+[a-zA-Z])   #
            $
          /x

          parts           = mbean.match( regex )
          mbeanType       = parts['type'].to_s.strip.tr( '. ', '' )
          mbean_type      = sprintf( '%s', mbeanType )
        end

        result.push(
          mbean_type.to_s => {
            'status'    => status,
            'timestamp' => timestamp,
            'host'      => host,
            'port'      => port,
            'request'   => request,  # OBSOLETE, can be removed
            'value'     => value
          }
        )

      end

      return result
    end



    def run()

      logger.debug( 'get monitored Servers' )

      monitoredServer = self.monitoredServer()

      logger.debug( "#{monitoredServer.keys}" )
      logger.debug( 'start' )

      monitoredServer.each do |h,d|

        logger.info( sprintf( 'Host: %s', h ) )

        prepared = @mc.get( Storage::Memcached.cacheKey( { :host => h, :pre => 'prepare' } ) )

        if( prepared == nil || prepared == false )

          result = false

          # no prepared data found ...
          # generate it
          options = {
            :host                  => h,
            :applicationConfigFile => @applicationConfig,
            :serviceConfigFile     => @serviceConfig
          }

          p = Prepare.new( options )
          result = p.buildMergedData()

          if( result == true )
            @mc.set( Storage::Memcached.cacheKey( { :host => h, :pre => 'prepare' } ), true )
          end
        else
          # roger, we have prepared datas
          # use them and do what you must do
          monitoredServer.each do |h,d|

            self.createBulkCheck( h )

          end
        end

      end

      logger.debug( 'stop' )

    end

  end

end

