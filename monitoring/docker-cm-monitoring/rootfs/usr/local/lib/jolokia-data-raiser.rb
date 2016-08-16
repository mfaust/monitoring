#!/usr/bin/ruby
#
# 12.08.2016 - Bodo Schulz
#
#
# v1.0.17

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'uri'
require 'socket'
require 'timeout'
require 'fileutils'
# require 'resolv-replace.rb'
require 'net/http'

require_relative 'jolokia_template'
require_relative 'tools'

# -----------------------------------------------------------------------------

class JolokiaDataRaiser

  attr_reader :status, :message, :services

  def initialize( settings = {}, applicationConfig, serviceConfig )

    @logDirectory   = settings['log_dir']      ? settings['log_dir']      : '/tmp/log'
    @cacheDirectory = settings['cache_dir']    ? settings['cache_dir']    : '/tmp/cache'
    @jolokiaHost    = settings['jolokia_host'] ? settings['jolokia_host'] : 'localhost'
    @jolokiaPort    = settings['jolokia_port'] ? settings['jolokia_port'] : 8080

    if( ! File.exist?( @logDirectory ) )
      Dir.mkdir( @logDirectory )
    end

    if( ! File.exist?( @cacheDirectory ) )
      Dir.mkdir( @cacheDirectory )
    end

    logFile = sprintf( '%s/data-raiser.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @currentDirectory    = File.expand_path( File.join( File.dirname( __FILE__ ) ) )

    @appConfigFile       = File.expand_path( applicationConfig )
    @serviceConfigFile   = File.expand_path( serviceConfig )

    @jolokiaApplications = nil
    @serviceConfig       = nil

    version              = '1.0.17'
    date                 = '2016-08-16'

    @log.info( '-----------------------------------------------------------------' )
    @log.info( ' JolokiaDataRaiser' )
    @log.info( "  Version #{version} (#{date})" )
    @log.info( '  Copyright 2016 Coremedia' )
    @log.info( "  cache directory located at #{@cacheDirectory}" )
    @log.info( '-----------------------------------------------------------------' )
    @log.info( '' )

  end


  def applicationConfig( applicationConfig )
    @appConfigFile  = File.expand_path( applicationConfig )
  end


  def serviceConfig( serviceConfig )
    @serviceConfigFile = File.expand_path( serviceConfig )
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

    port = data['port'] ? data['port'] : nil
    if( port != nil )

      serverUrl  = sprintf( 'http://%s:%s/serverStatus', host, port )

      uri        = URI.parse( serverUrl )
      http       = Net::HTTP.new( uri.host, uri.port )
      request    = Net::HTTP::Get.new( uri.request_uri )
      request.add_field('Content-Type', 'application/json')

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        @log.error( error )

        case error
        when Errno::ECONNREFUSED
          @log.error( 'connection refused' )
        when Errno::ECONNRESET
          @log.error( 'connection reset' )
        end
      else

        dir_path        = sprintf( '%s/%s', @cacheDirectory, host )
        save_file       = sprintf( 'bulk_%s.result', port )

        hash            = Hash.new()
        array           = Array.new()
        hash['mongodb'] =  JSON.parse( response.body )
        array.push( hash )

        File.open( sprintf( '%s/%s', dir_path, save_file ) , 'w' ) {|f| f.write( JSON.pretty_generate( array ) ) }
      end

    end
  end

  # merge hashes of configured (cm-service.json) and discovered data (discovery.json)
  def createHostConfig( data )

    data.each do |d,v|

      # merge data between discovered Services and our base configuration,
      # the dicovered ports are IMPORTANT
      if( @serviceConfig['services'][d] )
        data[d].merge!( @serviceConfig['services'][d] ) { |key, port| port }
      else
        @log.debug( sprintf( 'missing entry \'%s\'', d ) )
      end
    end

    return data

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

    metrics_tomcat       = @jolokiaApplications['tomcat']      # standard metrics for Tomcat

    data.each do |d,v|

      application = v['application'] ? v['application'] : nil
      solr_cores  = v['cores']       ? v['cores']       : nil
      metrics     = v['metrics']     ? v['metrics']     : nil

      v['metrics'] = Array.new()

      if( application )

        if( solr_cores != nil )
          v['metrics'].push( self.mergeSolrCores( @jolokiaApplications[application]['metrics'], solr_cores ) )
        end

        @jolokiaApplications[application]['metrics'].delete_if {|key| key['mbean'].match( '%CORE%' ) }

        v['metrics'].push( metrics_tomcat['metrics'] )
        v['metrics'].push( @jolokiaApplications[application]['metrics'] )
      end

      if( @jolokiaApplications[d] )
        v['metrics'].push( metrics_tomcat['metrics'] )
        v['metrics'].push( @jolokiaApplications[d]['metrics'] )
      end

      v['metrics'].compact!   # remove 'nil' from array
      v['metrics'].flatten!   # clean up and reduce depth

    end

    return data
  end


  # create an bulkset over all checks
  def createBulkCheck( host, data )

    dir_path  = sprintf( '%s/%s', @cacheDirectory, host )

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

        template = JolokiaTemplate.singleTemplate( properties )

        result.push( template )

      end

      file_data = JSON.pretty_generate( result )
      File.open( sprintf( '%s/%s', dir_path, save_file ) , 'w' ) {|f| f.write( file_data ) }

      result = []

    end
  end

  # send chek to our jolokia
  def sendChecks( file )

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

        response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https" ) do |http|
          http.request(request)
        end

        result = response.body

        @log.debug( 'reorganize data for later use' )

        begin
          result = self.reorganizeData( result )
          result = JSON.pretty_generate( result )

          dir_path  = sprintf( '%s/%s', @cacheDirectory, dest_host )
          save_file = sprintf( 'bulk_%s.result', dest_port )
          File.open( sprintf( '%s/%s', dir_path, save_file ) , 'w' ) {|f| f.write( result ) }

        rescue
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

      if( mbean.include?( 'module=' ) )
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



  def run( applicationConfig = nil, serviceConfig = nil )

    if( applicationConfig != nil )
      self.applicationConfig( applicationConfig )
    end

    if( serviceConfig != nil )
      self.serviceConfig( serviceConfig )
    end

    # read Application Configuration
    # they define all standard checks
    if( @jolokiaApplications.to_s == '' )

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
    else
      @log.debug( 'jolokiaApplications is set' )
    end

    # read Service Configuration
    #
    if( @serviceConfig.to_s == '' )

      @log.debug( 'read defines off Services Properties' )

      begin

        if( File.exist?( @serviceConfigFile ) )
          @serviceConfig      = JSON.parse( File.read( @serviceConfigFile ) )
        else
          @log.error( sprintf( 'Config File %s not found!', @serviceConfigFile ) )
          exit 1
        end

      rescue JSON::ParserError => e

        @log.error( 'wrong result (no json)')
        @log.error( e )
        exit 1
      end
    else
      @log.debug( 'serviceConfig is set' )
    end

    # ----------------------------------------------------------------------------------------

    @log.debug( 'get monitored Servers' )
    monitoredServer = monitoredServer( @cacheDirectory )

    file_name = 'discovery.json'
    save_file = 'mergedHostData.json'

    data = Hash.new()

    monitoredServer.each do |h|

      @log.info( sprintf( 'Host: %s', h ) )

      dir_path  = sprintf( '%s/%s', @cacheDirectory, h )

      file = sprintf( '%s/%s', dir_path, file_name )

      if( File.exist?( file ) == true )

#        @log.debug( file )

        data = JSON.parse( File.read( file ) )

        # TODO
        # create data for mySQL, Postgres
        #
        if( data['mongodb'] )
          self.mongoDBData( h, data['mongodb'] )
        end

        @log.debug( 'create Hostconfiguration' )
        d = self.createHostConfig( data )

        @log.debug( 'merge Data between Property Files and discovered Services' )
        d = self.mergeData( d )

#        @log.debug( JSON.pretty_generate( d ) )

        if( ! File.exist?( sprintf( '%s/%s', dir_path, save_file ) ) )

          @log.debug( 'save merged data' )
          merged = JSON.pretty_generate( d )
          File.open( sprintf( '%s/%s', dir_path, save_file ) , 'w' ) {|f| f.write( merged ) }
        end

        @log.debug( 'create bulk Data for Jolokia' )
        self.createBulkCheck( h, d )

        Dir.chdir( dir_path )
        Dir.glob( "bulk_**.json" ) do |f|

          if( File.exist?( f ) == true )
#             @log.debug( f )

            @log.debug( 'send data to Jolokia' )
            self.sendChecks( f )
          end
#          if( FileTest.directory?( f ) )
#            monitoredServer.push( File.basename( f ) )
#          end
        end
      end
    end

    self.logMark()


#    json = JSON.pretty_generate( data )
#    File.open( sprintf( '%s/%s', dir_path, file_name ) , 'w' ) {|f| f.write( metricsResult ) }

#    createBulkCheck( host, port, data )

  end



end
