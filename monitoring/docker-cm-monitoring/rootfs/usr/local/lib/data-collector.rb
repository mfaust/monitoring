#!/usr/bin/ruby
#
# 13.09.2016 - Bodo Schulz
#
#
# v1.2.1

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'uri'
require 'socket'
require 'timeout'
require 'fileutils'
require 'net/http'

require_relative 'discover'
require_relative 'tools'

# -----------------------------------------------------------------------------

class DataCollector

  attr_reader :status, :message, :services, :reDiscovery

  def initialize( settings = {} )

    @logDirectory      = settings['log_dir']               ? settings['log_dir']               : '/tmp/log'
    @cacheDirectory    = settings['cache_dir']             ? settings['cache_dir']             : '/tmp/cache'
    @jolokiaHost       = settings['jolokia_host']          ? settings['jolokia_host']          : 'localhost'
    @jolokiaPort       = settings['jolokia_port']          ? settings['jolokia_port']          : 8080
    applicationConfig  = settings['applicationConfigFile'] ? settings['applicationConfigFile'] : nil
    serviceConfig      = settings['serviceConfigFile']     ? settings['serviceConfigFile']     : nil

    if( ! File.exist?( @logDirectory ) )
      Dir.mkdir( @logDirectory )
    end

    if( ! File.exist?( @cacheDirectory ) )
      Dir.mkdir( @cacheDirectory )
    end

    logFile = sprintf( '%s/data-collector.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end


    if( applicationConfig == nil or serviceConfig == nil )
      msg = 'no Configuration File given'
      puts msg
      @log.error( msg )

      exit 1
    end

    self.applicationConfig( applicationConfig )
    self.readConfiguration()

    @settings            = settings
    @jolokiaApplications = nil

    version              = '1.2.1'
    date                 = '2016-09-13'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' CoreMedia - DataCollector' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( "  cache directory located at #{@cacheDirectory}" )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

#     @discovery = ServiceDiscovery.new( @settings )

  end


  def applicationConfig( applicationConfig )
    @appConfigFile  = File.expand_path( applicationConfig )
  end


  def readConfiguration()

    # read Application Configuration
    # they define all standard checks
    @log.debug( 'read defines of Application Properties' )

    begin

      if( File.exist?( @appConfigFile ) )
        @config      = JSON.parse( File.read( @appConfigFile ) )

        if( @config['jolokia']['applications'] != nil )
          @jolokiaApplications = @config['jolokia']['applications']
        end

      else
        @log.error( sprintf( 'Application Config File %s not found!', @appConfigFile ) )
        exit 1
      end
    rescue JSON::ParserError => e

      @log.error( 'wrong result (no json)')
      @log.error( e )
      exit 1
    end

  end


  def checkDiscoveryFileAge( f )

    @log.debug( f )
    @log.debug( File.mtime( f ).strftime("%Y-%m-%d %H:%M:%S") )
    @log.debug( Time.now() )
    @log.debug( Time.now() - ( 60*10 ) )

    if( File.mtime(f) < ( Time.now() - ( 60*10 ) ) )
      @log.debug( '  - trigger service discover' )
      @reDiscovery = true
    else
      @reDiscovery = false
    end

    return @reDiscovery
  end


  def logMark()

    t      = Time.now
    minute = t.min
    second = t.sec

    @wroteTick= false

    if( [0,10,20,30,40,50].include?( minute ) and second < 27 )

      if( @wroteTick == false )
        @log.info( ' ----- TICK - TOCK ---- ' )
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

        @log.error( error )

        case error
        when Errno::EHOSTUNREACH
          @log.error( 'Host unreachable' )
        when Errno::ECONNREFUSED
          @log.error( 'Connection refused' )
        when Errno::ECONNRESET
          @log.error( 'Connection reset' )
        end
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

      application = v['application'] ? v['application'] : nil
      solr_cores  = v['cores']       ? v['cores']       : nil
      metrics     = v['metrics']     ? v['metrics']     : nil

      v['metrics'] = Array.new()

      if( application )

        applicationMetrics = tomcatApplication[application]['metrics']

        if( solr_cores != nil )
          v['metrics'].push( self.mergeSolrCores( applicationMetrics , solr_cores ) )
        end

        # remove unneeded Templates
        tomcatApplication[application]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

        v['metrics'].push( metricsTomcat['metrics'] )
        v['metrics'].push( applicationMetrics )
      end

      if( tomcatApplication[d] )
        v['metrics'].push( metricsTomcat['metrics'] )
        v['metrics'].push( tomcatApplication[d]['metrics'] )
      end

      v['metrics'].compact!   # remove 'nil' from array
      v['metrics'].flatten!   # clean up and reduce depth

    end

    return data
  end


  def jolokiaTemplateOBSOLETE( params = {} )

    mbean       = params['mbean']
    server_name = params['server_name']
    server_port = params['server_port']

    target = {
      "type" => "read",
      "mbean" => "#{mbean}",
      "target" => {
        "url" => "service:jmx:rmi:///jndi/rmi://#{server_name}:#{server_port}/jmxrmi",
      },
      "config" => { "ignoreErrors" => true }
    }

    attributes = []

    if( params['attributes'] != nil )
      params['attributes'].split(',').each do |t|
        attributes.push( t.to_s )
      end

      target['attribute'] = attributes
    end

    return target

  end


  # create an bulkset over all checks
  def createBulkCheckOBSOLETE( host, data )

    cachedHostDirectory  = sprintf( '%s/%s', @cacheDirectory, host )

    result  = Array.new()

    data.each do |m,v|

      port    = v['port']
      metrics = v['metrics']

      save_file = sprintf( 'bulk_%s_%s.json', port, m )

      if( metrics.count == 0 )
        next
      end

      metrics.each do |e|

        properties = {
          'mbean'       => e['mbean'],
          'attributes'  => e['attribute'] ? e['attribute'] : nil,
          'server_name' => host,
          'server_port' => port
        }

        template = self.jolokiaTemplate( properties )

        result.push( template )

      end

      file_data = JSON.pretty_generate( result )
      File.open( sprintf( '%s/%s', cachedHostDirectory, save_file ) , 'w' ) {|f| f.write( file_data ) }

      result = []

    end
  end

  # send check to our jolokia
  def sendChecksOBSOLETE( file )

    result       = nil

    # if our jolokia proxy available?
    if( ! portOpen?( @jolokiaHost, @jolokiaPort ) )
      @log.error( sprintf( 'The Jolokia Service (%s:%s) are not available', @jolokiaHost, @jolokiaPort ) )
    else

      serverUrl  = sprintf( "http://%s:%s/jolokia", @jolokiaHost, @jolokiaPort )

      uri        = URI.parse( serverUrl )
      http       = Net::HTTP.new( uri.host, uri.port )

      data       = JSON.parse( File.read( file ) )

      # "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
      course_line = /
        ^                   # Starting at the front of the string
        (.*):\/\/           # all after the douple slashes
        (?<host>.+\S)       # our hostname
        :                   # seperator between host and port
        (?<port>\d+)        # our port
      /x

      dest_uri  = data[0]['target']['url']
      parts     = dest_uri.match( course_line )
      dest_host = "#{parts['host']}".strip
      dest_port = "#{parts['port']}".strip

      # if our destination service (behind the jolokia proxy) available?
      if( ! portOpen?( dest_host, dest_port ) )

        @log.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', dest_port, dest_host ) )
      else

        request = Net::HTTP::Post.new(
          uri.request_uri,
          initheader = {'Content-Type' =>'application/json'}
        )
        request.body = data.to_json

        #Default read timeout is 60 secs
        response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https", :read_timeout => 5 ) do |http|
          begin
            http.request(request)
          rescue Exception => e
            @log.warn("Cannot execute request to #{uri.request_uri}, cause: #{e}")
            @log.debug("Cannot execute request to #{uri.request_uri}, cause: #{e}, request body: #{request.body}")
            return
          end
        end

        result = response.body

#         @log.debug( 'reorganize data for later use' )

        begin
          result = self.reorganizeData( result )

          result = JSON.pretty_generate( result )

          cachedHostDirectory  = sprintf( '%s/%s', @cacheDirectory, dest_host )
          save_file = sprintf( "#{file}.result")
          File.open( sprintf( '%s/%s', cachedHostDirectory, save_file ) , 'w' ) {|f| f.write( result ) }

        rescue => e
          @log.error( e )
          @log.error( 'can\'t send data to jolokia service' )
        end

      end
    end

  end

  # reorganize data to later simple find
  def reorganizeData( data )

    if( data == nil )
      @log.error( "      no data for reorganize" )
      @log.error( "      skip" )
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

      if(mbean.include?( 'Cache.Classes' ))
        regex = /
          CacheClass=
          "(?<type>.+[a-zA-Z])"
          /x
        parts           = mbean.match( regex )
        cacheClass       = "#{parts['type']}".split('.').last
        mbean_type = "CacheClasses#{cacheClass}"

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
        mbeanModule     = "#{parts['module']}".strip.tr( '. ', '' )
        mbeanPool       = "#{parts['pool']}".strip.tr( '. ', '' )
        mbeanType       = "#{parts['type']}".strip.tr( '. ', '' )
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
        mbeanBean       = "#{parts['bean']}".strip.tr( '. ', '' )
        mbeanType       = "#{parts['type']}".strip.tr( '. ', '' )
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
        mbeanName       = "#{parts['name']}".strip.tr( '. ', '' )
        mbeanType       = "#{parts['type']}".strip.tr( '. ', '' )
        mbean_type      = sprintf( '%s%s', mbeanType, mbeanName )

      elsif( mbean.include?( 'solr') )

        regex = /
          ^                     # Starting at the front of the string
          solr\/                #
          (?<core>.+[a-zA-Z]):  #
          (.*)                  #
          type=                 #
          (?<type>.+[a-zA-Z])   #
          $
        /x

        parts           = mbean.match( regex )
        mbeanCore       = "#{parts['core']}".strip.tr( '. ', '' )
        mbeanCore[0]    = mbeanCore[0].to_s.capitalize
        mbeanType       = "#{parts['type']}".tr( '. /', '' )
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
        mbeanType       = "#{parts['type']}".strip.tr( '. ', '' )
        mbean_type      = sprintf( '%s', mbeanType )
      end

      result.push(
        mbean_type.to_s => {
          'status'    => status,
          'timestamp' => timestamp,
          'request'   => request,
          'value'     => value
        }
      )

    end

    return result
  end


  def checkHostAndService( targetUrl )

    result = false
    # "service:jmx:rmi:///jndi/rmi://moebius-16-tomcat:2222/jmxrmi"
    regex = /
      ^                   # Starting at the front of the string
      (.*):\/\/           # all after the douple slashes
      (?<host>.+\S)       # our hostname
      :                   # seperator between host and port
      (?<port>\d+)        # our port
    /x

    # prepare
    parts     = targetUrl.match( regex )
    destHost  = "#{parts['host']}".strip
    destPort  = "#{parts['port']}".strip

    @log.debug( sprintf( 'check Port %s on Host %s for sending data', destPort, destHost ) )

    result = portOpen?( destHost, destPort )

    if( result == false )
      @log.error( sprintf( 'The Port %s on Host %s is not open, skip sending data', destPort, destHost ) )
    end

    return result

  end

  # to reduce i/o we work better in memory ...
  def createBulkCheck( data )

    hosts  = data.keys
    checks = Array.new()
    array  = Array.new()

    result = {
      :timestamp   => Time.now().to_i
    }

    hosts.each do |h|

      @log.debug( sprintf( 'create bulk checks for \'%s\'', h ) )

      services = data[h][:data] ? data[h][:data] : nil

      @log.info( sprintf( '%d services found', services.count ) )

      services.each do |s,v|

        @log.debug( sprintf( '  - %s', s ) )

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
          when 'postgres'
            # Postgres
          else
            # all others
          end
        else

          metrics.each do |e|

            target = {
              "type"   => "read",
              "mbean"  => "#{e['mbean']}",
              "target" => { "url" => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", h, port ) },
              "config" => { "ignoreErrors" => true }
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

      self.sendChecksToJolokia( result )

      checks.clear()
      result.clear()
    end
  end


  def sendChecksToJolokia( data )

    if( portOpen?( @jolokiaHost, @jolokiaPort ) == false )
      @log.error( sprintf( 'The Jolokia Service (%s:%s) are not available', @jolokiaHost, @jolokiaPort ) )

      return
    end

    serverUrl  = sprintf( "http://%s:%s/jolokia", @jolokiaHost, @jolokiaPort )

    uri        = URI.parse( serverUrl )
    http       = Net::HTTP.new( uri.host, uri.port )

    hostname = data[:hostname] ? data[:hostname] : nil
    checks   = data[:checks]   ? data[:checks]   : nil

    result = {
      :hostname  => hostname,
      :timestamp => Time.now().to_i
    }

    checks.each do |c|

      c.each do |v,i|

        @log.info( sprintf( '%d checks for service %s found', i.count, v ) )

        if( ! i[0]['target'] )

          case v
          when 'mysql'
            # MySQL
            result[v] = self.mysqlData( hostname )
          when 'mongodb'
            # MongoDB
            result[v] = self.mongoDBData( hostname )
          when 'postgres'
            # Postgres
          else
            # all others
          end

        else

          targetUrl = i[0]['target']['url']

          if( self.checkHostAndService( targetUrl ) == true )

            request = Net::HTTP::Post.new(
              uri.request_uri,
              initheader = { 'Content-Type' =>'application/json' }
            )
            request.body = i.to_json

            # default read timeout is 60 secs
            response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https", :read_timeout => 5 ) do |http|
              begin
                http.request( request )
              rescue Exception => e

                msg = 'Cannot execute request to %s, cause: %s'
                @log.warn( sprintf( msg, uri.request_uri, e ) )
                @log.debug( sprintf( ' -> request body: %s', request.body ) )
                return
              end
            end

            result[v] = self.reorganizeData( response.body )

            tmpResultFile = sprintf( '%s/%s/monitoring.tmp'    , @cacheDirectory, hostname )
            resultFile    = sprintf( '%s/%s/monitoring.result' , @cacheDirectory, hostname )

            File.open( tmpResultFile , 'w' ) { |f| f.write( JSON.generate( result ) ) }
            File.rename( tmpResultFile, resultFile )

          end
        end
      end
    end
  end

  # merge Data
  def buildMergedData( host )

    discoveryFile        = sprintf( '%s/%s/discovery.json'     , @cacheDirectory, host )
    mergedDataFile       = sprintf( '%s/%s/mergedHostData.json', @cacheDirectory, host )

    if( File.exist?( mergedDataFile ) )

      @log.debug( 'read merged data' )
      result = JSON.parse( File.read( mergedDataFile ) )

    else

      @log.debug( 'build merged data' )

      data = JSON.parse( File.read( discoveryFile ) )

      # TODO
      # create data for mySQL, Postgres
      #
      if( data['mongodb'] )
        self.mongoDBData( host, data['mongodb'] )
      end

      if( data['mysql'] )
        self.mysqlData( host, data['mysql'] )
      end

      if( data['postgres'] )
        self.postgresData( host, data['postgres'] )
      end

      @log.debug( 'merge Data between Property Files and discovered Services' )
      d = self.mergeData( data )

      @log.debug( 'save merged data' )
      result = JSON.generate( d )

      File.open( mergedDataFile , 'w' ) { |f| f.write( result ) }

    end

    return result

  end


  def run()

    @log.debug( 'get monitored Servers' )
    monitoredServer = monitoredServer( @cacheDirectory )

    discoveryFile   = 'discovery.json'
    mergedDataFile  = 'mergedHostData.json'

    data = Hash.new()

    monitoredServer.each do |h|

      @log.info( sprintf( 'Host: %s', h ) )

      cachedHostDirectory  = sprintf( '%s/%s', @cacheDirectory, h )

      file = sprintf( '%s/%s', cachedHostDirectory, discoveryFile )

      if( File.exist?( file ) == true )

#         if( self.checkDiscoveryFileAge( file ) == true )
#
#           # re.start the service discovery
#           @discovery.refreshHost( h )
#
#         end

        d = buildMergedData( h )

        data[h] = {
          :data      => d,
          :timestamp => Time.now().to_i
        }

      end
    end

    self.createBulkCheck( data )

    self.logMark()

  end



end
