#!/usr/bin/ruby
#
# 08.08.2016 - fpanteko
#
#
# v1.1.0
# -----------------------------------------------------------------------------

require 'socket'
require 'timeout'
# require 'logger'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

require_relative 'logging'
require_relative 'discover'
require_relative 'tools'

# -------------------------------------------------------------------------------------------------------------------

class Grafana

  attr_reader :version
  attr_reader :status
  attr_reader :message

  include Logging

  def initialize( settings = {} )

    @logDirectory      = settings[:logDirectory]      ? settings[:logDirectory]      : '/tmp'
    @cacheDirectory    = settings[:cacheDirectory]    ? settings[:cacheDirectory]    : '/var/tmp/monitoring'
    @templateDirectory = settings[:templateDirectory] ? settings[:templateDirectory] : '/var/tmp/templates'
    @grafanaHost       = settings[:grafanaHost]       ? settings[:grafanaHost]       : 'localhost'
    @grafanaPort       = settings[:grafanaPort]       ? settings[:grafanaPort]       : 3000
    @grafanaPath       = settings[:grafanaPath]       ? settings[:grafanaPath]       : nil
    @grafanaAPIUser    = settings[:grafanaAPIUser]    ? settings[:grafanaAPIUser]    : 'admin'
    @grafanaAPIPass    = settings[:grafanaAPIPass]    ? settings[:grafanaAPIPass]    : 'admin'
    @memcacheHost      = settings[:memcacheHost]      ? settings[:memcacheHost]      : nil
    @memcachePort      = settings[:memcachePort]      ? settings[:memcachePort]      : nil

    @grafanaURI        = sprintf( 'http://%s:%s%s', @grafanaHost, @grafanaPort, @grafanaPath )

    @supportMemcache   = false

#     logFile        = sprintf( '%s/grafana.log', @logDirectory )
#     file           = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#     file.sync      = true
#     @log           = Logger.new(file, 'weekly', 1024000)
#     logger.level     = Logger::INFO
#     logger.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
#     logger.formatter = proc do |severity, datetime, progname, msg|
#       "[#{datetime.strftime(logger.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
#     end

    if( @memcacheHost != nil && @memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @supportMemcache = true

    end

    version              = '1.3.3'
    date                 = '2016-12-15'

    logger.info( '-----------------------------------------------------------------' )
    logger.info( ' CoreMedia - Grafana Dashboard Management' )
    logger.info( "  Version #{version} (#{date})" )
    logger.info( '  Copyright 2016 Coremedia' )

    if( @supportMemcache == true )
      logger.info( sprintf( '  Memcache Support enabled (%s:%s)', @memcacheHost, @memcachePort ) )
    end
    logger.info( "  Backendsystem #{@grafanaURI}" )
    logger.info( '-----------------------------------------------------------------' )
    logger.info( '' )

  end


  def prepare( host )

    logger.debug( sprintf(  'prepare( %s )', host ) )

    hostInfo = hostResolve( host )

    ip    = hostInfo[:ip]    ? hostInfo[:ip]    : nil # dnsResolve( host )
    short = hostInfo[:short] ? hostInfo[:short] : nil
    long  = hostInfo[:long]  ? hostInfo[:long]  : nil

    @shortHostname        = short
    @grafanaHostname      = host.gsub( '.', '-' )

    @discoveryFile        = sprintf( '%s/%s/discovery.json'       , @cacheDirectory, host )
    @mergedHostFile       = sprintf( '%s/%s/mergedHostData.json'  , @cacheDirectory, host )
    @monitoringResultFile = sprintf( '%s/%s/monitoring.result'    , @cacheDirectory, host )

  end



  def checkGrafana?()

    uri = URI( sprintf( '%s/api/orgs/1', @grafanaURI ) )

    # set timeouts
    openTimeout = 2
    readTimeout = 8
    response    = []

    begin

      http     = Net::HTTP.new( uri.host, uri.port )
      request  = Net::HTTP::Get.new( uri.request_uri )
      request.basic_auth( @grafanaAPIUser, @grafanaAPIPass )

      response = Net::HTTP.start( uri.hostname, uri.port, use_ssl: uri.scheme == "https", :read_timeout => readTimeout, :open_timeout => openTimeout ) do |http|
        begin
          http.request( request )
        rescue Exception => e

          msg = 'Cannot execute request to %s, cause: %s'
          logger.warn( sprintf( msg, uri.request_uri, e ) )
          logger.debug( sprintf( ' -> request body: %s', request.body ) )
          return false
        end
      end

    rescue Exception => e
      logger.error( e )
      logger.error( 'Timeout' )
      return false
    end

    responseCode = response.code.to_i

    return true

  end


  def supportMbean?( data, service, mbean, key = nil )

    result = false

    s   = data[service] ? data[service] : nil

    if( s == nil )
      logger.debug( sprintf( 'no service %s found', service ) )
      return false
    end

    mbeanExists  = s.detect { |s| s[mbean] }

    if( mbeanExists == nil )
      logger.debug( sprintf( 'no mbean %s found', mbean ) )
      return false
    end

    mbeanExists  = mbeanExists[mbean]    ? mbeanExists[mbean]    : nil
    mbeanStatus  = mbeanExists['status'] ? mbeanExists['status'] : 999

    if( mbeanStatus.to_i != 200 )

      logger.debug( sprintf( 'mbean %s found, but status %d', mbean, mbeanStatus ) )
      return false
    end

    if( mbeanExists != nil && key == nil )

      result = true
    elsif( mbeanExists != nil && key != nil )

      logger.debug( sprintf( 'look for key %s', key ) )

      mbeanValue = mbeanExists['value'] ? mbeanExists['value'] : nil

      if( mbeanValue == nil )
        return false
      end

      if( mbeanValue.class.to_s == 'Hash' )
        mbeanValue = mbeanValue.values.first
      end

      attribute = mbeanValue[ key ] ? mbeanValue[ key ]  : nil

      if( attribute == nil || ( attribute.is_a?(String) && attribute.include?( 'ERROR' ) ) )

        return false
      end
      return true
    end

    return result
  end


  def beanAvailable?( host, service, bean, key = nil )

    json = Hash.new()

    if( @supportMemcache == true )

      memcacheKey = cacheKey( 'result', host, service )

      for y in 1..10
        result      = @mc.get( memcacheKey )

        if( result != nil )

          json = { service => result }

          break
        else
          logger.debug( sprintf( 'Waiting for data %s ... %d', memcacheKey, y ) )
          sleep( 3 )
        end
      end
    else

      fileName = sprintf( "%s/%s/monitoring.result", @cacheDirectory, host )

      for y in 1..10

        if( File.exist?( fileName ) )
          sleep( 1 )
          file = File.read( fileName )
          break
        end

        logger.debug( sprintf( 'Waiting for file %s ... %d', fileName, y ) )
        sleep( 3 )
      end

      if( file )
        json   = JSON.parse( file )
      end

    end

    begin
      result = self.supportMbean?( json, service, bean, key  )
    rescue JSON::ParserError => e

      logger.error('wrong result (no json)')
      logger.error(e)

      result = false
    end

    return result
  end


  def addAnnotations( templateJson )

    # add or overwrite annotations
    annotations = '
      {
        "list": [
          {
            "name": "created",
            "enable": false,
            "iconColor": "rgb(93, 227, 12)",
            "datasource": "events",
            "tags": "%HOST% created&set=intersection"
          },
          {
            "name": "destoyed",
            "enable": false,
            "iconColor": "rgb(227, 57, 12)",
            "datasource": "events",
            "tags": "%HOST% destroyed&set=intersection"
          },
          {
            "name": "Load Tests",
            "enable": false,
            "iconColor": "rgb(26, 196, 220)",
            "datasource": "events",
            "tags": "%HOST% loadtest&set=intersection"
          },
          {
            "name": "Deployments",
            "enable": false,
            "iconColor": "rgb(176, 40, 253)",
            "datasource": "events",
            "tags": "%HOST% deployment&set=intersection"
          }
        ]
      }
    '

    if( templateJson.is_a?( String ) )
      templateJson = JSON.parse( templateJson )
    end

    annotation = templateJson.dig( 'dashboard', 'annotations' )

    if( annotation != nil )
      templateJson['dashboard']['annotations'] = JSON.parse( annotations )
    end

    return templateJson

  end


  def addTags( templateJson )

    tags = @additionalTags

    # add tags
    if( templateJson.is_a?( String ) )
      templateJson = JSON.parse( templateJson )
    end

    currentTags = templateJson.dig( 'dashboard', 'tags' )

    if( currentTags != nil && tags != nil )

      currentTags << tags
      currentTags.flatten!.sort!

      templateJson['dashboard']['tags'] = currentTags
    end

    if( templateJson.is_a?( Hash ) )
      templateJson = JSON.generate( templateJson )
    end

    return templateJson

  end


  # add dashboards for a host
  def addDashbards( host, options = {} )

    logger.info( sprintf( 'Adding dashboards for host \'%s\'', host ) )

    @additionalTags = options['tags']     ? options['tags']     : []
    createOverview  = options['overview'] ? options['overview'] : false

    if( self.checkGrafana?() == false )

      result = {
        :status      => 500,
        :name        => host,
        :message     => 'grafana is not available'
      }

      return result
    end

    self.prepare( host )

    # determine services from discovery.json file, e.g. cae-live, master-live-server, caefeeder-live
    discoveryJson = self.getJsonFromFile( @discoveryFile )

    if( discoveryJson != nil )

      services       = discoveryJson.keys
      logger.debug( "Found services: #{services}" )

      # fist, we must remove strange services
      servicesTmp = *services
      servicesTmp.delete( 'mysql' )
      servicesTmp.delete( 'postgres' )
      servicesTmp.delete( 'mongodb' )
      servicesTmp.delete( 'node_exporter' )
      servicesTmp.delete( 'demodata-generator' )

      # determine type of service from mergedHostData.json file, e.g. cae, caefeeder, contentserver
      mergedHostJson = self.getJsonFromFile( @mergedHostFile )

      services.each do |service|

        serviceTemplate         = nil
        additionalTemplatePaths = Array.new()

#         logger.debug( ',---------------------------------------------------------' )
#         logger.debug( sprintf( 'service: %s', service ) )

        description    = discoveryJson.dig( service, 'description' )
        template       = discoveryJson.dig( service, 'template' )
        memcacheKey    = cacheKey( 'result', host, service )
        # cae-live-1 -> cae-live
        serviceName    = removePostfix( service )
        normalizedName = normalizeService( service )

#         logger.debug( sprintf( 'description: %s', description ) )
#         logger.debug( sprintf( 'memcacheKey: %s', memcacheKey ) )
#         logger.debug( sprintf( 'custom template: %s', template ) )
#         logger.debug( sprintf( 'service Name: %s', serviceName ) )
#         logger.debug( sprintf( 'normalized Name: %s', normalizedName ) )

#         logger.debug( '+---------------------------------------------------------' )
#         logger.debug( "Searching templates paths for service: #{service}" )

        if( template != nil )

          serviceTemplate = self.getTemplateForService( template )
        else
          # get templates for service
          serviceTemplate = self.getTemplateForService( serviceName )
        end
#         logger.debug( sprintf( ' => %s', serviceTemplate ) )
#         logger.debug( '+---------------------------------------------------------' )

        if( ! ['mongodb', 'mysql', 'postgres'].include?( serviceName ) )
          additionalTemplatePaths.push( *self.getTemplateForService( 'tomcat' ) )
        end

        # get templates for service type
#         if( mergedHostJson != nil )
#
#           # not longer needed
# #          serviceType = mergedHostJson[service]["application"]
# #          if( serviceType )
# #            additionalTemplatePaths.push( *self.getTemplatePathsForServiceType( serviceType ) )
# #          end
#         else
#           logger.error( sprintf( 'file %s doesnt exist', @mergedHostFile ) )
#         end

        if( ! serviceTemplate.to_s.empty? )

          logger.debug( sprintf( "Found Template paths: %s, %s" , serviceTemplate , additionalTemplatePaths ) )

          options = {
            :description             => description,
            :serviceName             => serviceName,
            :normalizedName          => normalizedName,
            :serviceTemplate         => serviceTemplate,
            :additionalTemplatePaths => additionalTemplatePaths
          }

          self.generateServiceTemplate( serviceName, options )

        end
        logger.debug( '`---------------------------------------------------------' )
      end

      # Overview Template
      if( createOverview == true )
        self.generateOverviewTemplate( services )
      end

      # LicenseInformation
      if( servicesTmp.include?( 'content-management-server' ) || servicesTmp.include?( 'master-live-server' ) || servicesTmp.include?( 'replication-live-server' ) )
        self.generateLicenseTemplate( host, services )
      end

      namedTemplate = Array.new()

      # MemoryPools for many Services
      namedTemplate.push( 'cm-memory-pool.json' )

      # CAE Caches
      if( servicesTmp.include?( 'cae-preview' ) || servicesTmp.include?( 'cae-live' ) )

        namedTemplate.push( 'cm-cae-cache-classes.json' )

        if( self.beanAvailable?( host, 'cae-preview', 'CacheClassesIBMAvailability' ) == true )
          namedTemplate.push( 'cm-cae-cache-classes-ibm.json' )
        end
      end

      self.addNamedTemplate( namedTemplate )

    end

    dashboards = self.searchDashboards( @shortHostname )
    count      = 0

    if( dashboards != false )

      count = dashboards.count()

      status  = 200
      message = sprintf( '%d dashboards added', count )
    else
      status  = 500
      message = 'Error for adding Dashboads'
    end

    @status = status

    result = {
      :status      => status,
      :name        => host,
      :message     => message
    }

    return result

  end


  # delete the dashboards for a host
  def deleteDashboards( host, tags = [] )

    logger.debug( sprintf( 'Deleting dashboards for host %s', host ) )

    dashboards = Array.new()

    if( self.checkGrafana?() == false )

      result = {
        :status      => 500,
        :name        => host,
        :message     => 'grafana is not available'
      }

      return result
    end

    self.prepare( host )

#     if( tags.count() != 0 )
#
#       logger.debug( '  and tags:' )
#
#       tags.each do |t|
#
#         logger.debug( sprintf( '    - %s', t ) )
#
# #        dashboards.push( self.searchDashboards( t ) )
#       end
#     end

    dashboards.push( self.searchDashboards( @shortHostname ) )
    dashboards.flatten!

    if( dashboards != false )

      count = dashboards.count()

      logger.debug( sprintf( 'found %d dashboards for delete', count ) )

      if( count.to_i == 0 )

        status  = 204
        message = 'No Dashboards found'
      else

        dashboards.each do |i|

          if( (i.include?"group") && ( !host.include?"group") )
            # Don't delete group templates except if deletion is forced
            next
          end

          logger.debug( sprintf( '  - %s', i ) )

          uri = URI( sprintf( '%s/api/dashboards/%s', @grafanaURI, i ) )

          begin
            Net::HTTP.start( uri.host, uri.port ) do |http|
              request = Net::HTTP::Delete.new( uri.path )
              request.basic_auth( @grafanaAPIUser, @grafanaAPIPass )

              response     = http.request( request )
              responseCode = response.code.to_i

              # TODO
              # Errorhandling
              if( responseCode != 200 )
                # 200 – Created
                # 400 – Errors (invalid json, missing or invalid fields, etc)
                # 401 – Unauthorized
                # 412 – Precondition failed
                logger.error( sprintf( ' [%s] - Error', responseCode ) )
                logger.error( response.body )
              end
            end

            status  = 200
            message = sprintf( '%d dashboards deleted', count )
          rescue Exception => e
            logger.error( e )
            logger.error( e.backtrace )

            status  = 404
            message = sprintf( 'internal error: %s', e )
          end
        end
      end
    end

    @status = status

    result = {
      :status      => status,
      :name        => host,
      :message     => message
    }

    return result

  end


  # list dashboards with tag
  def searchDashboards( tag )

    logger.debug( sprintf( 'Search dashboards with tag \'%s\'', tag ) )

    uri = URI( sprintf( '%s/api/search?query=&tag=%s', @grafanaURI, tag ) )

    response = nil
    Net::HTTP.start( uri.host, uri.port ) do |http|
      request = Net::HTTP::Get.new( uri.request_uri )

      request.add_field( 'Content-Type', 'application/json' )
      request.basic_auth( @grafanaAPIUser, @grafanaAPIPass )

      response     = http.request( request )
      responseCode = response.code.to_i

      if( responseCode == 200 )

        responseBody  = JSON.parse( response.body )
        dashboards    = responseBody.collect { |item| item['uri'] }

        return( dashboards )

      # TODO
      # Errorhandling
      #if( responseCode != 200 )
      else
        # 200 – Created
        # 400 – Errors (invalid json, missing or invalid fields, etc)
        # 401 – Unauthorized
        # 412 – Precondition failed
        logger.error( sprintf( ' [%s] - Error for search Dashboards', responseCode ) )
        logger.error( response.body )
      end

    end

  end


  def listDashboards( host )

    if( self.checkGrafana?() == false )

      result = {
        :status      => 500,
        :message     => 'grafana is not available'
      }

      return result
    end

    self.prepare( host )

    data = self.searchDashboards( @shortHostname )

    data.each do |d|
      d.gsub!( sprintf( 'db/%s-', @shortHostname ), '' )
    end

    if( data.count == 0 )

      return {
        :status     => 204,
        :message    => 'no Dashboards found'
      }
    end

    return {
      :status     => 200,
      :count      => data.count,
      :dashboards => data
    }

  end


  def getTemplatePathsForServiceType( serviceType )

    paths = Array.new()
    logger.debug( serviceType )
    dirs  = Dir["#{@templateDirectory}/service-types/#{serviceType}"]
    count = dirs.count()

    logger.debug( dir )
    logger.debug( count )

    if( count != 0 )

      logger.debug( "Found dirs: #{dirs}" )
      dirs.each do |dir|
        paths.push(*Dir["#{dir}/cm*.json"])
      end
    end

     logger.debug( paths )

    return paths
  end


  def getTemplateForService( serviceName )

    template = sprintf( '%s/services/%s.json', @templateDirectory, serviceName )
    logger.debug( template )

    if( ! File.exist?( template ) )

      logger.error( sprintf( 'no template for service %s found', serviceName ) )

      template = nil
    end

    return template
  end


  # OBSOLETE
  def getTemplatePathsForService( serviceName )

    logger.error( 'getTemplatePathsForService => OBSOLETE' )

    paths = Array.new()
    dirs  = Dir["#{@templateDirectory}/services/#{serviceName}*"]
    count = dirs.count()

    logger.debug( serviceName )
    logger.debug( dir )
    logger.debug( count )

    if( count != 0 )

      logger.debug("Found dirs: #{dirs}")
      dirs.each do |dir|
        paths.push(*Dir["#{dir}/cm*.json"])
      end
    end

    logger.debug( paths )

    return paths
  end


  def generateOverviewTemplate( services )

    logger.info( 'Create Overview Template' )

    rows = getOverviewTemplateRows(services)
    rows = rows.join(',')

    template = %(
      {
        "dashboard": {
          "id": null,
          "title": "%SHORTHOST% = Overview",
          "originalTitle": "%SHORTHOST% = Overview",
          "tags": [ "%TAG%", "overview" ],
          "style": "dark",
          "timezone": "browser",
          "editable": true,
          "hideControls": false,
          "sharedCrosshair": false,
          "rows": [
            #{rows}
          ],
          "time": {
            "from": "now-3m",
            "to": "now"
          },
          "timepicker": {
            "refresh_intervals": [ "1m", "2m" ],
            "time_options": [ "3m", "5m", "15m" ]
          },
          "templating": {
            "list": []
          },
          "annotations": {
            "list": []
          },
          "refresh": "1m",
          "schemaVersion": 12,
          "version": 0,
          "links": []
        }
      }
    )

    if( validJson?( template ) )
      sendTemplateToGrafana( template )
    end

  end


  def getOverviewTemplateRows( services )

    rows = Array.new()
    dir  = Array.new()
    srv  = Array.new()

    services.each do |s|
      srv << removePostfix( s )
    end

    regex = /
      ^                       # Starting at the front of the string
      \d\d-                   # 2 digit
      (?<service>.+[a-zA-Z])  # service name
      \.tpl                   #
    /x

    Dir.chdir( sprintf( '%s/overview', @templateDirectory )  )

    dirs = Dir.glob( "**.tpl" )

    dirs.sort!

    dirs.each do |f|

      if( f =~ regex )
        part = f.match(regex)
        dir << part['service'].to_s.strip
      end
    end

    # TODO
    # add overwriten templates!


    intersect = dir & srv

    intersect.each do |service|

      service  = removePostfix( service )
      template = Dir.glob( sprintf( '%s/overview/**%s.tpl', @templateDirectory, service ) ).first

      if( File.exist?( template ) )

        tpl = File.read( template )
        rows << tpl
      end
    end

    logger.debug( " templates: #{dirs}" )
    logger.debug( " services : #{srv}" )
    logger.debug( " use      : #{intersect}" )

    return rows

  end


  def generateLicenseTemplate( host, services )

    logger.info( 'create License Templates' )

    rows           = Array.new()
    contentServers = ['content-management-server', 'master-live-server', 'replication-live-server']
    intersect      = contentServers & services

#     logger.debug( " contentServers: #{contentServers}" )
#     logger.debug( " services      : #{services}" )
#     logger.debug( " use           : #{intersect}" )

    licenseHead    = sprintf( '%s/licenses/licenses-head.json' , @templateDirectory )
    licenseUntil   = sprintf( '%s/licenses/licenses-until.json', @templateDirectory )
    licensePart    = sprintf( '%s/licenses/licenses-part.json' , @templateDirectory )

    intersect.each do |service|

      if( self.beanAvailable?( host, service, 'Server', 'LicenseValidUntilHard' ) == true )

        logger.info( sprintf( 'found License Information for Service %s', service ) )

        if( File.exist?( licenseUntil ) )

          tpl = File.read( licenseUntil )

          tpl.gsub!( '%SERVICE%', normalizeService( service ) )

          rows << tpl
        end

      end
    end

    if( File.exist?( licenseHead ) )
      rows << File.read( licenseHead )
    end

    intersect.each do |service|

      if( self.beanAvailable?( host, service, 'Server', 'ServiceInfos' ) == true )

        logger.info( sprintf( 'found Service Information for Service %s', service ) )

        if( File.exist?( licensePart ) )

          tpl = File.read( licensePart )

          tpl.gsub!( '%SERVICE%', normalizeService( service ) )

          if( service == 'replication-live-server' )

            tpl.gsub!( 'service_info-publisher' , 'service_info-webserver' )
            tpl.gsub!( 'Publisher', 'Webserver' )

          end

          rows << tpl
        end
      end
    end

    if( rows.count == 1 )
      # only the license Head is into the array
      logger.info( 'We have no information about Licenses' )
      return
    end

    rows = rows.join(',')

    template = %(
      {
        "dashboard": {
          "id": null,
          "title": "%SHORTHOST% - Licenses",
          "originalTitle": "%SHORTHOST% - Licenses",
          "tags": [ "%TAG%", "licenses" ],
          "style": "dark",
          "timezone": "browser",
          "editable": true,
          "hideControls": false,
          "sharedCrosshair": false,
          "rows": [
            #{rows}
          ],
          "time": {
            "from": "now-2m",
            "to": "now"
          },
          "timepicker": {
            "refresh_intervals": [ "1m", "2m", "10m" ],
            "time_options": [ "2m", "15m" ]
          },
          "templating": {
            "list": []
          },
          "annotations": {
            "list": []
          },
          "refresh": "2m",
          "schemaVersion": 12,
          "version": 0,
          "links": []
        }
      }
    )

    if( validJson?( template ) )
      sendTemplateToGrafana( template )
    end

  end


  def generateServiceTemplate( serviceName, options = {} )

    logger.info( sprintf( 'Creating dashboard for \'%s\'', serviceName ) )
    logger.debug( options )

    description             = options[:description]             ? options[:description]             : nil
    serviceName             = options[:serviceName]             ? options[:serviceName]             : nil
    normalizedName          = options[:normalizedName]          ? options[:normalizedName]          : nil
    serviceTemplate         = options[:serviceTemplate]         ? options[:serviceTemplate]         : nil
    additionalTemplatePaths = options[:additionalTemplatePaths] ? options[:additionalTemplatePaths] : nil

    logger.debug( sprintf( '  - template %s', File.basename( serviceTemplate ).strip ) )

    templateFile = File.read( serviceTemplate )
    templateJson = JSON.parse( templateFile )

    if( templateJson['dashboard'] && templateJson['dashboard']['rows'] )

      rows = templateJson['dashboard']['rows']

      additionalTemplatePaths.each do |additionalTemplate|

        logger.debug( sprintf( '  - merge with template %s', File.basename( additionalTemplate ).strip ) )

        additionalTemplateFile = File.read( additionalTemplate )
        additionalTemplateJson = JSON.parse( additionalTemplateFile )

        if( additionalTemplateJson['dashboard']['rows'] )
          templateJson['dashboard']['rows'] = additionalTemplateJson['dashboard']['rows'].concat(rows)
        end
      end
    end

    templateJson = self.addAnnotations( templateJson )

    json = JSON.generate( templateJson )

    json.gsub!( '%DESCRIPTION%', description )
    json.gsub!( '%SERVICE%'    , normalizedName )

    self.sendTemplateToGrafana( json, normalizedName )

  end

  # use array to add more than on template
  def addNamedTemplate( templates = [] )

    logger.info( 'add named template' )

    if( templates.count() != 0 )

      templates.each do |template|

        filename = sprintf( '%s/%s', @templateDirectory, template )

        if( File.exist?( filename ) )

          logger.info( sprintf( '  - %s', File.basename( filename ).strip ) )

#         file = File.read( filename )
#         file = self.addAnnotations( file )
#         file = JSON.generate( file )

          self.sendTemplateToGrafana(
            JSON.generate(
              self.addAnnotations(
                File.read( filename )
              )
            )
          )
        end
      end
    end
  end


  def sendTemplateToGrafana( templateFile, serviceName = nil )

    templateFile = regenerateGrafanaTemplateIDs( templateFile )

    if( !templateFile )
      logger.error( 'Cannot create dashboard, invalid json' )
      return
    end

    templateFile.gsub!( '%HOST%'     , @grafanaHostname )
    templateFile.gsub!( '%SHORTHOST%', @shortHostname )
    templateFile.gsub!( '%TAG%'      , @shortHostname )
    if( serviceName )
      templateFile.gsub!( '%SERVICE%'  , serviceName )
    end

    templateFile = self.addTags( templateFile )

    grafanaDbUri = URI( sprintf( '%s/api/dashboards/db', @grafanaURI ) )

    response = nil
    Net::HTTP.start(grafanaDbUri.host, grafanaDbUri.port) do |http|

      request = Net::HTTP::Post.new grafanaDbUri.request_uri
      request.add_field('Content-Type', 'application/json')
      request.basic_auth( @grafanaAPIUser, @grafanaAPIPass )
      request.body = templateFile

      response     = http.request( request )
      responseCode = response.code.to_i

      # TODO
      # Errorhandling
      if( responseCode != 200 )
        # 200 – Created
        # 400 – Errors (invalid json, missing or invalid fields, etc)
        # 401 – Unauthorized
        # 412 – Precondition failed
        logger.error( sprintf( ' [%s] - Error for sendTemplateToGrafana', responseCode ) )
        logger.error( response.body )
#        logger.error( sprintf( '   templateFile: %s', templateFile ) )
        logger.error( sprintf( '   serviceName : %s', serviceName ) )
      end

    end
  end


  def getJsonFromFile( filename, useMemcache = false )

    file = nil

    if( useMemcache == true )

      key         = filename

      for y in 1..10
        json      = @mc.get( key )

        if( json != nil )
          break
        else
          logger.debug( sprintf( 'Waiting for data %s ... %d', key, y ) )
          sleep( 3 )
        end
      end

      if( json == nil )
        logger.error( sprintf( 'No Data in Memcache for key %s found!', filename ) )
        return nil
      end

    else

      for y in 1..10
        if( File.exist?( filename ) )
          file = File.read( filename )
          break
        end
        logger.debug( "  Waiting for file #{filename} ... #{y}" )
        sleep( 3 )
      end

      if( !file )
        logger.error( sprintf( 'File %s not found!', filename ) )
        return nil
      end

      begin
        json = JSON.parse(file)
      rescue JSON::ParserError => e
        logger.error('wrong result (no json)')
        logger.error(e)
        exit 1
      end
    end

    return json
  end


  def addGroupOverview( hosts, force = false )

    logger.info("Create Group Overview for #{hosts}")

    if (force)
      deleteDashboards("group")
    end

    rows = Array.new()

    hosts.each do |host|

      self.prepare( host )

      templateRows = Array.new()

      discoveryFile = sprintf( '%s/%s/discovery.json', @cacheDirectory, host )
      discoveryJson = getJsonFromFile( discoveryFile )

      if( discoveryJson == nil )

        logger.error( "No discovery.json for host #{host}" )

        result = {
          :status  => 500,
          :name    => host,
          :message => "Unknown host. Please add host to monitoring."
        }
        return result

      else

        services     = discoveryJson.keys
        templateRows = getOverviewTemplateRows( services )

        grafanaHost  = host
        grafanaHost.gsub( '.', '-' )

        templateRows.each do |row|
          row.gsub!( '%SHORTHOST%', @shortHostname )
          row.gsub!( '%HOST%', grafanaHost )
        end

        titleRow = %(
          {
            "collapse": false,
            "editable": true,
            "height": "25px",
            "panels": [
              {
                "content": "<h2><left><bold>#{@shortHostname}</bold></left></h2>",
                "editable": true,
                "error": false,
                "id": 70,
                "isNew": true,
                "links": [],
                "mode": "html",
                "span": 2,
                "title": "",
                "transparent": true,
                "type": "text"
              }
            ],
            "title": ""
          }
        )
        rows.push( titleRow )
        rows.push( templateRows ).flatten!
      end
    end

    rows = rows.join(',')

    template = %(
      {
        "dashboard": {
          "id": null,
          "title": "Group",
          "originalTitle": "Group -- %SHORTHOST% - Overview",
          "tags": [ %TAG% ],
          "style": "dark",
          "timezone": "browser",
          "editable": true,
          "hideControls": false,
          "sharedCrosshair": false,
          "rows": [
            #{rows}
          ],
          "time": {
            "from": "now-3m",
            "to": "now"
          },
          "timepicker": {
            "refresh_intervals": [ "1m", "2m" ],
            "time_options": [ "3m", "5m", "15m" ]
          },
          "templating": {
            "list": []
          },
          "annotations": {
            "list": []
          },
          "refresh": "1m",
          "schemaVersion": 12,
          "version": 0,
          "links": []
        }
      }
    )

    shortHosts = ''
    tags       = '"overview"'

    hosts.each do |host|
      shortHosts = sprintf( '%s %s'   , shortHosts, @shortHostname )
      tags       = sprintf( '%s, "%s"', tags      , @shortHostname )
    end

    if hosts.length > 1
      tags = sprintf( '%s, "group"', tags )
    end

    template.gsub!( '%SHORTHOST%', shortHosts )
    template.gsub!( '%TAG%'      , tags )

    if( validJson?( template ) )
      sendTemplateToGrafana( template )
    end

    result = {
      :status  => 200,
      :name    => hosts,
      :message => "OK"
    }

    return result

  end



end

