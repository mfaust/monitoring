#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.3.1

# -----------------------------------------------------------------------------

require 'json'
require 'uri'
require 'socket'
require 'timeout'
require 'dalli'
require 'fileutils'
require 'net/http'
require 'time'
require 'date'
require 'time_difference'

require_relative 'logging'
require_relative 'message-queue'
require_relative 'database'
#require_relative 'tools'

# -----------------------------------------------------------------------------

class Time
  def add_minutes(m)
    self + (60 * m)
  end
end

# -----------------------------------------------------------------------------

class DataCollector

  include Logging

  def initialize( settings = {} )

    @logDirectory      = settings[:logDirectory]          ? settings[:logDirectory]          : '/var/log/monitoring'
    @cacheDirectory    = settings[:cacheDirectory]        ? settings[:cacheDirectory]        : '/var/cache/monitoring'
    @jolokiaHost       = settings[:jolokiaHost]           ? settings[:jolokiaHost]           : 'localhost'
    @jolokiaPort       = settings[:jolokiaPort]           ? settings[:jolokiaPort]           : 8080
    @memcacheHost      = settings[:memcacheHost]          ? settings[:memcacheHost]          : 'loclahost'
    @memcachePort      = settings[:memcachePort]          ? settings[:memcachePort]          : 11211
    @mqHost            = settings[:mqHost]                ? settings[:mqHost]                : 'localhost'
    @mqPort            = settings[:mqPort]                ? settings[:mqPort]                : 11300
    @mqQueue           = settings[:mqQueue]               ? settings[:mqQueue]               : 'mq-collector'

    applicationConfig  = settings[:applicationConfigFile] ? settings[:applicationConfigFile] : nil
    serviceConfig      = settings[:serviceConfigFile]     ? settings[:serviceConfigFile]     : nil

    @db                = Storage::Database.new()

    @MQSettings = {
      :beanstalkHost => @mqHost,
      :beanstalkPort => @mqPort
    }

    @DEBUG             = false

    if( ! File.exist?( @cacheDirectory ) )
      Dir.mkdir( @cacheDirectory )
    end

    if( applicationConfig == nil or serviceConfig == nil )
      msg = 'no Configuration File given'
      logger.error( msg )

      exit 1
    end

    # add cache setting
    # eg.cache for 2 min here. default options is never expire
    memcacheOptions = {
      :compress   => true,
      :namespace  => 'monitoring',
      :expires_in => 60*2
    }

    @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

    self.applicationConfig( applicationConfig )
    self.readConfiguration()

    @settings            = settings
    @jolokiaApplications = nil

    version              = '1.4.0'
    date                 = '2017-01-05'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - DataCollector' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016 Coremedia' )
    logger.info( "  cache directory located at #{@cacheDirectory}" )
    logger.info( "  Memcache Service #{@memcacheHost}:#{@memcachePort}" )
    logger.info( "  message Queue Service #{@mqHost}:#{@mqPort}/#{@mqQueue}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

  end


  def applicationConfig( applicationConfig )
    @appConfigFile  = File.expand_path( applicationConfig )
  end


  def readConfiguration()

    # read Application Configuration
    # they define all standard checks
    logger.debug( 'read defines of Application Properties' )

    begin

      if( File.exist?( @appConfigFile ) )

        @config      = YAML.load_file( @appConfigFile )

        if( @config['jolokia']['applications'] != nil )
          @jolokiaApplications = @config['jolokia']['applications']
        end

      else
        logger.error( sprintf( 'Application Config File %s not found!', @appConfigFile ) )
        exit 1
      end
    rescue Exception

      logger.error( 'wrong result (no yaml)')
      logger.error( "#{$!}" )
      exit 1
    end

  end


  def checkHostDataAge( host, updated )

    result = false
    quorum = 10      # in minutes

    n = Time.now()
    t = Time.at( updated )
    t = t.add_minutes( quorum ) + 15

    difference = TimeDifference.between( t, n ).in_each_component
    difference = difference[:minutes].ceil

    if( difference > quorum + 1 )

      logger.debug( sprintf( ' now       : %s', n.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
      logger.debug( sprintf( ' timestamp : %s', t.to_datetime.strftime("%d %m %Y %H:%M:%S") ) )
      logger.debug( sprintf( ' difference: %d', difference ) )

      # quorum reached
#       p = MessageQueue::Producer.new( @MQSettings )
#
#       job = {
#         cmd:  'refresh',
#         node: host,
#         from: 'data-collector',
#         payload: { "annotation": false }
#       }.to_json
#
#       logger.debug( p.addJob( 'mq-discover', job ) )

      result = true
    end

    return result

  end


  def logMark()

    t      = Time.now
    minute = t.min
    second = t.sec

    @wroteTick= false

    if( [0,10,20,30,40,50].include?( minute ) and second < 27 )

      if( @wroteTick == false )
        logger.info( ' ----- TICK - TOCK ---- ' )
      end
      @wroteTick = true
    else
      @wroteTick = false
    end

  end


  def mongoDBData( host, data = {} )

    port = data['port'] ? data['port'] : 28017

    if( port != nil )

      serverUrl  = sprintf( 'http://%s:%s/serverStatus', host, port )

      uri        = URI.parse( serverUrl )
      http       = Net::HTTP.new( uri.host, uri.port )
      request    = Net::HTTP::Get.new( uri.request_uri )
      request.add_field('Content-Type', 'application/json')

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        logger.error( error )

        case error
        when Errno::EHOSTUNREACH
          logger.error( 'Host unreachable' )
        when Errno::ECONNREFUSED
          logger.error( 'Connection refused' )
        when Errno::ECONNRESET
          logger.error( 'Connection reset' )
        end
      rescue Exception => e

        logger.error( "An error occurred for connection: #{e}" )

      else

        data            = JSON.parse( response.body )

        return data
      end

    end
  end


  def mysqlData( host, data = {} )

    user = data['user'] ? data['user'] : 'cm_management'
    pass = data['pass'] ? data['pass'] : 'cm_management'
    port = data['port'] ? data['port'] : 3306

    if( port != nil )

      # TODO
      # we need an low-level-priv User for Monitoring!
      settings = {
        'log_dir'   => @logDirectory,
        'mysqlHost' => host,
        'mysqlUser' => user,
        'mysqlPass' => pass
      }

      require_relative 'mysql-status'

      if( ! @mysql )
        @mysql = MysqlStatus.new( settings )
      end

      hash            = Hash.new()
      array           = Array.new()
      mysqlData       = @mysql.run()

      if( mysqlData == false )
        mysqlData   = JSON.generate( { :status => 500 } )
      end

      data           = JSON.parse( mysqlData )

      return data

    end

  end


  def postgresData( host, data = {} )

    # WiP and nore sure
    return

    user = data['user'] ? data['user'] : nil
    pass = data['pass'] ? data['pass'] : nil
    port = data['port'] ? data['port'] : nil

    if( port != nil )

      settings = {
        'log_dir'      => @logDirectory,
        'postgresHost' => host,
        'postgresUser' => 'coremedia',
        'postgresPass' => 'coremedia'
      }

      require_relative 'postgres-status'

      pgsql = PostgresStatus.new( settings )
      pgsql.run()

    end

  end


  def nodeExporterData( host, data = {} )

    logger.debug()

    logger.debug( host )
    logger.debug( data )

    port = data[:port] ? data[:port] : 9100

    if( port != nil )

      settings = {
        :host => host,
        :port => port
      }

      require_relative 'nodeexporter_data'

      nodeData = NodeExporter.new()
      result   = JSON.generate( nodeData.run( settings ) )
      data     = JSON.parse( result )

      return data
    end

  end


  def internalMemcacheData( host )


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


  def mergeData( data = {} )

    tomcatApplication = Marshal.load( Marshal.dump( @config['jolokia']['applications'] ) )
    metricsTomcat     = tomcatApplication['tomcat']      # standard metrics for Tomcat

    data.each do |d,v|

#       logger.debug( " service  #{d}" )
#       logger.debug( " data     #{v}" )

      application = v[:data]['application'] ? v[:data]['application'] : nil
      solr_cores  = v[:data]['cores']       ? v[:data]['cores']       : nil
      metrics     = v[:data]['metrics']     ? v[:data]['metrics']     : nil

#       logger.debug( application )
#       logger.debug( solr_cores )
#       logger.debug( metrics )

      v[:data]['metrics'] = Array.new()

      if( application != nil )

        logger.debug( application )

        application.each do |a|

          if( tomcatApplication[a] )

            applicationMetrics = tomcatApplication[a]['metrics']

#             logger.debug( "  add #{applicationMetrics}" )

            if( solr_cores != nil )
              v[:data]['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
            end

            # remove unneeded Templates
            tomcatApplication[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

            v[:data]['metrics'].push( metricsTomcat['metrics'] )
            v[:data]['metrics'].push( applicationMetrics )

          end
        end

      end

      if( tomcatApplication[d] )

#         logger.debug( "found #{d} in tomcat application" )
#         logger.debug metricsTomcat['metrics']

        v[:data]['metrics'].push( metricsTomcat['metrics'] )
        v[:data]['metrics'].push( tomcatApplication[d]['metrics'] )
      end

      v[:data]['metrics'].compact!   # remove 'nil' from array
      v[:data]['metrics'].flatten!   # clean up and reduce depth

#       sleep(1)

    end

#     logger.debug( JSON.pretty_generate( data ) )

#     logger.debug( '------------------------------------------' )

    return data

#     data.each do |d,v|
#
#       logger.debug( d )
#       logger.debug( v )
#
#       application = v['application'] ? v['application'] : nil
#       solr_cores  = v['cores']       ? v['cores']       : nil
#       metrics     = v['metrics']     ? v['metrics']     : nil
#
#       v['metrics'] = Array.new()
#
#       if( application != nil )
#
#         logger.debug( application )
#
#         application.each do |a|
#
#           if( tomcatApplication[a] )
#             applicationMetrics = tomcatApplication[a]['metrics']
#
#             if( solr_cores != nil )
#               v['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
#             end
#
#             # remove unneeded Templates
#             tomcatApplication[a]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }
#
#             v['metrics'].push( metricsTomcat['metrics'] )
#             v['metrics'].push( applicationMetrics )
#
#           end
#         end
#
#       end
#
#       if( tomcatApplication[d] )
#         v['metrics'].push( metricsTomcat['metrics'] )
#         v['metrics'].push( tomcatApplication[d]['metrics'] )
#       end
#
#       v['metrics'].compact!   # remove 'nil' from array
#       v['metrics'].flatten!   # clean up and reduce depth
#
#
#       sleep(1)
#
#     end
#
#     return data
  end

  # reorganize data to later simple find
  def reorganizeData( data )

    if( data == nil )
      logger.error( "      no data for reorganize" )
      logger.error( "      skip" )
      return nil
    end

    data    = JSON.parse( data )
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

    logger.debug( sprintf( 'check Port %s on Host %s for sending data', destPort, destHost ) )

    result = portOpen?( destHost, destPort )

    if( result == false )
      logger.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', destPort, destHost ) )
    end

    return result

  end

  # create a singulary json for every services to send them to the jolokia service
  #
  def createBulkCheck( data )

    hosts  = data.keys
    checks = Array.new()
    array  = Array.new()

    result = {
      :timestamp   => Time.now().to_i
    }

    hosts.each do |h|

      logger.debug( sprintf( 'create bulk checks for \'%s\'', h ) )

      services      = data[h][:data] ? data[h][:data] : nil
      servicesCount = services.count

      if( servicesCount == 0 )
        logger.debug( 'no services found. skip ... ' )
        next
      end

      logger.debug( sprintf( '%d services found', servicesCount ) )

      # if Host available -> break
      hostStatus = isRunning?( h )

      if( hostStatus == false )

        logger.error( sprintf( '  Host are not available! (%s)', hostStatus ) )

        next
      end

      services.each do |s,v|

        logger.debug( sprintf( '  - %s', s ) )

        port    = v['port']
        metrics = v['metrics']
        bulk    = Array.new()

        if( metrics.count == 0 )
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
              'target' => { 'url' => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", h, port ) },
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

      result[:hostname] = h
      result[:services] = *services.keys
      result[:checks]   = *checks

      # send json to jolokia
      self.sendChecksToJolokia( result )

      checks.clear()
      result.clear()
    end

  end

  # send json data to jolokia and save the result in an memory storage (e.g. memcache)
  #
  def sendChecksToJolokia( data )

    if( portOpen?( @jolokiaHost, @jolokiaPort ) == false )
      logger.error( sprintf( 'The Jolokia Service (%s:%s) are not available', @jolokiaHost, @jolokiaPort ) )

      return
    end

    serverUrl = sprintf( "http://%s:%s/jolokia", @jolokiaHost, @jolokiaPort )

    uri       = URI.parse( serverUrl )
    http      = Net::HTTP.new( uri.host, uri.port )

    hostname  = data[:hostname] ? data[:hostname] : nil
    checks    = data[:checks]   ? data[:checks]   : nil

    result    = {
      :hostname  => hostname,
      :timestamp => Time.now().to_i
    }

    checks.each do |c|

      c.each do |v,i|

        logger.debug( sprintf( '%d checks for service %s found', i.count, v ) )

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

          if( @DEBUG == true )

            tmpFile = sprintf( '%s/%s/request-%s.json'    , @cacheDirectory, hostname,v )
            File.open( tmpFile , 'w' ) { |f| f.write( JSON.pretty_generate( i ) ) }

          end

          targetUrl = target['url']

          if( self.checkHostAndService( targetUrl ) == true )

            request = Net::HTTP::Post.new(
              uri.request_uri,
              initheader = { 'Content-Type' =>'application/json' }
            )
            request.body = i.to_json

            # default read timeout is 60 secs
            response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https", :read_timeout => 8 ) do |http|
              begin
                http.request( request )
              rescue Exception => e

                msg = 'Cannot execute request to %s, cause: %s'
                logger.warn( sprintf( msg, uri.request_uri, e ) )
                logger.debug( sprintf( ' -> request body: %s', request.body ) )
                return
              end
            end

            result[v] = self.reorganizeData( response.body )

#            tmpResultFile = sprintf( '%s/%s/monitoring.tmp'    , @cacheDirectory, hostname )
#            resultFile    = sprintf( '%s/%s/monitoring.result' , @cacheDirectory, hostname )
#
#            File.open( tmpResultFile , 'w' ) { |f| f.write( JSON.generate( result ) ) }
#            File.rename( tmpResultFile, resultFile )
#
#            if( @supportMemcache == true )
#
#              key = sprintf( 'result__%s__%s', hostname, v )
#
#              logger.debug( key )
#
#              @mc.set( key, result[v] )
#
#              if( @DEBUG == true )
#                logger.debug( @mc.stats( :items ) )
#                logger.debug( JSON.pretty_generate( @mc.get( key ) ) )
#              end
#
#            end

          end
        end

        if( @supportMemcache == true )

          key = cacheKey( 'result', hostname, v )
          @mc.set( key, result[v] )

#           if( @DEBUG == true )
#             logger.debug( @mc.stats( :items ) )
#             logger.debug( JSON.pretty_generate( @mc.get( key ) ) )
#           end
        else

          tmpResultFile = sprintf( '%s/%s/monitoring.tmp'    , @cacheDirectory, hostname )
          resultFile    = sprintf( '%s/%s/monitoring.result' , @cacheDirectory, hostname )

          File.open( tmpResultFile , 'w' ) { |f| f.write( JSON.generate( result ) ) }
          File.rename( tmpResultFile, resultFile )
        end

      end
    end
  end

  # merge Data between Property Files and discovered Services
  # creates mergedHostData.json for every Node
  def buildMergedData( host )

    logger.debug( "buildMergedData( #{host} )" )

    # Database

    data = @db.discoveryData( { :ip => host, :short => host } )

    if( data == nil )
      return
    end

#     logger.debug( JSON.pretty_generate( data[host.to_s] ) )




#     discoveryFile        = sprintf( '%s/%s/discovery.json'     , @cacheDirectory, host )
#     mergedDataFile       = sprintf( '%s/%s/mergedHostData.json', @cacheDirectory, host )
#
#     if( ! File.exist?( discoveryFile ) )
#
#       logger.error( sprintf( 'no discovered Services found' ) )
#
#       return ( {} )
#
#     end

#     if( File.exist?( mergedDataFile ) )
#
#       logger.debug( 'read merged data' )
#       result = JSON.parse( File.read( mergedDataFile ) )
#
#       logger.debug( ( result ) )
#     else
#
#       logger.debug( 'build merged data' )
#
#       data = JSON.parse( File.read( discoveryFile ) )
#
#       # TODO
#       # create data for mySQL, Postgres
#       #
#       if( data['mongodb'] )
#         self.mongoDBData( host, data['mongodb'] )
#       end
#
#       if( data['mysql'] )
#         self.mysqlData( host, data['mysql'] )
#       end
#
#       if( data['postgres'] )
#         self.postgresData( host, data['postgres'] )
#       end
#
#       if( data['node_exporter'] )
#
#         option = {
#           :port => 9100
#         }
#         self.nodeExporterData( host, option )
#       end


      logger.debug( 'merge Data between Property Files and discovered Services' )
      result = self.mergeData( data[host.to_s] )

      logger.debug( 'save merged data' )

      resultJson = JSON.generate( result )

      logger.debug( resultJson )

#       File.open( mergedDataFile , 'w' ) { |f| f.write( resultJson ) }

#     end

    return result

  end


  def monitoredServer()

    d = @db.nodes( { :status => 1 } )

#     logger.debug( d )
#     logger.debug( d.keys )

    return d

  end


  def run()

    logger.debug( 'get monitored Servers' )

    data = Hash.new()

    monitoredServer = self.monitoredServer()

    logger.debug( 'start' )
    monitoredServer.each do |h,d|

      logger.info( sprintf( 'Host: %s', h ) )

      updated = d.first.dig( :updated )

      self.checkHostDataAge( h, updated )

       data[h] = {
         :data      => self.buildMergedData( h ),
         :timestamp => Time.now().to_i
       }

    end
    logger.debug( 'stop' )

#    self.createBulkCheck( data )

#    self.logMark()

  end

end
