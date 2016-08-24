#!/usr/bin/ruby
#
# 08.08.2016 - fpanteko
#
#
# v0.7.4
# -----------------------------------------------------------------------------

require 'socket'
require 'timeout'
require 'logger'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

require_relative 'discover'
require_relative 'tools'

# -------------------------------------------------------------------------------------------------------------------

class Grafana

  def initialize( settings = {} )

    @logDirectory      = settings['log_dir']      ? settings['log_dir']      : '/tmp'
    @cacheDirectory    = settings['cache_dir']    ? settings['cache_dir']    : '/var/tmp/monitoring'
    @templateDirectory = settings['template_dir'] ? settings['template_dir'] : '/var/tmp/templates'

    @grafanaHost       = settings['grafana_host'] ? settings['grafana_host'] : 'localhost'
    @grafanaPort       = settings['grafana_port'] ? settings['grafana_port'] : 3000
    @grafanaPath       = settings['grafana_path'] ? settings['grafana_path'] : nil

    @grafanaURI        = sprintf( 'http://%s:%s%s', @grafanaHost, @grafanaPort, @grafanaPath )

    logFile            = sprintf( '%s/grafana.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end
  end


  def prepare( host )

    @shortHostname    = self.shortHostname( host )
    @grafanaHostname  = host.gsub( '.', '-' )

    @discoveryFile    = sprintf( '%s/%s/discovery.json'     , @cacheDirectory, host )
    @mergedHostFile   = sprintf( '%s/%s/mergedHostData.json', @cacheDirectory, host )

  end

  def shortHostname( hostname )

    if( ! isIp?( hostname ) )
      shortHostname   = hostname.split( '.' ).first
    else
      shortHostname   = hostname
    end

    return shortHostname

  end


  def supportMbean?( filename, mbean, key = nil )

    result = false

    if( File.exist?( filename ) )

      file = File.read( filename )

      begin
        json = JSON.parse( file )
      rescue JSON::ParserError => e
        @log.error('wrong result (no json)')
        @log.error(e)

        return false
      end

      service      = json.detect { |s| s[mbean] }
      mbeanExists  = service[ mbean ] ? service[ mbean ] : nil

      if( mbeanExists != nil and key == nil )

        result = true
      elsif( mbeanExists != nil and key != nil )

        keyExists = mbeanExists['value'][ key ] ? mbeanExists['value'][ key ]  : nil

        result    = keyExists != nil ? true : false
      end

    end

    return result
  end


  def applicationPort( application )

    port = nil
    mergedHostJson = getJsonFromFile( @mergedHostFile )

    s = mergedHostJson[application] ? mergedHostJson[application] : nil
    if( s != nil )
      port = s['port'] ? s['port'] : nil
    end

    return port
  end

  # add dashboards for a host
  def addDashbards(host, recreate = false)

    @log.debug("Adding dashboards for host #{host}, recreate: #{recreate}")

    if( recreate )
      deleteDashboards( host )
    end

    self.prepare( host )

    # determine services from discovery.json file, e.g. cae-live, master-live-server, caefeeder-live
    discoveryJson = getJsonFromFile( @discoveryFile )

    if( discoveryJson != nil )

      services       = discoveryJson.keys
      # determine type of service from mergedHostData.json file, e.g. cae, caefeeder, contentserver
      mergedHostJson = getJsonFromFile( @mergedHostFile )

      self.generateOverviewTemplate( services )
      self.generateLicenseTemplate( host, services )

      @log.debug("Found services: #{services}")

      services.each do |service|

        serviceTemplatePaths    = Array.new()
        additionalTemplatePaths = Array.new()

        @log.debug("Searching templates paths for service: #{service}")

        # cae-live-1 -> cae-live
        serviceName = removePostfix(service)

        # get templates for service
        serviceTemplatePaths = *getTemplatePathsForService(serviceName)

        if (!['mongodb','postgres'].include? serviceName)
          additionalTemplatePaths.push(*getTemplatePathsForService("tomcat"))
        end

        # get templates for service type
        if( mergedHostJson != nil )

          serviceType = mergedHostJson[service]["application"]
          if( serviceType )
            additionalTemplatePaths.push(*getTemplatePathsForServiceType(serviceType))
          end
        else
          @log.error( sprintf( 'file %s doesnt exists', @mergedHostFile ) )
        end

        @log.debug( "Found Template paths: #{serviceTemplatePaths}, #{additionalTemplatePaths}")
        generateServiceTemplate( serviceName, serviceTemplatePaths, additionalTemplatePaths )

      end

    end
  end


  # delete the dashboards for a host
  def deleteDashboards( host )

    @log.debug("Deleting dashboards for host #{host}")

    dashboards = self.searchDashboards( host )

    if( dashboards != false )

      count = dashboards.count()

      @log.debug( sprintf( 'found %d dashboards for delete', count ) )

      if( count.to_i == 0 )
        return
      end

      @log.debug("Deleting Grafana Dashboards: #{dashboards}")

      dashboards.each do |i|
        uri = URI( sprintf( '%s/api/dashboards/%s', @grafanaURI, i ) ) #  "http://localhost/grafana/api/dashboards/#{i}")
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Delete.new(uri.path)
          request.basic_auth 'admin', 'admin'
          response = http.request request
          @log.debug("Deleted Dashboard #{i}, ok: #{response.code}")
        end
      end

    end
  end


  # delete the dashboards for a host
  def searchDashboards( tag )

    @log.debug( sprintf( 'Search dashboards with tag %s', tag ) )

    uri = URI( sprintf( '%s/api/search?query=&tag=%s', @grafanaURI, tag ) )

    @log.debug("Grafana Uri: #{uri}")

    response = nil

    http     = Net::HTTP.new( uri.host, uri.port )
    request  = Net::HTTP::Get.new( uri.request_uri )
    request.basic_auth( 'admin', 'admin' )
    response = http.request( request )

    responseCode = response.code.to_i

    if( responseCode >= 200 && responseCode <= 299 ) || ( responseCode >= 400 && responseCode <= 499 )

      responseBody  = JSON.parse( response.body )
      dashboards    = responseBody.collect { |item| item['uri'] }

      return( dashboards )
    else
      @log.info("No dashboards found")
      @log.error( "GET on #{uri} failed: HTTP #{response.code} - #{response.body}" )
      return false
    end

  end


  #cae-live-1 -> cae-live
  def removePostfix(service)

    if( service =~ /\d/ )

      lastPart = service.split("-").last
      service  = service.chomp("-#{lastPart}")
#       @log.debug("Chomped service: #{service}")
    end

    return service

  end


  def getTemplatePathsForServiceType(serviceType)

    paths = Array.new()
#    @log.debug(serviceType)
    dirs  = Dir["#{@templateDirectory}/service-types/#{serviceType}"]
    count = dirs.count()

    if( count != 0 )

#       @log.debug("Found dirs: #{dirs}")
      dirs.each do |dir|
        paths.push(*Dir["#{dir}/cm*.json"])
      end
    end

    return paths
  end


  def getTemplatePathsForService(serviceName)

    paths = Array.new()
    dirs  = Dir["#{@templateDirectory}/services/#{serviceName}*"]
    count = dirs.count()

    if( count != 0 )

#       @log.debug("Found dirs: #{dirs}")
      dirs.each do |dir|
        paths.push(*Dir["#{dir}/cm*.json"])
      end
    end

    return paths
  end


  def generateOverviewTemplate( services )

    rows = Array.new()
    dir  = Array.new()

    regex = /
      ^                      # Starting at the front of the string
      \d\d-                   # 2 digit
      (?<service>.+[a-zA-Z]) # service name
      \.tpl                   #
    /x

    Dir.chdir( sprintf( '%s/overview', @templateDirectory )  )

    dirs = Dir.glob( "**.tpl" )
    dirs = dirs.sort_by{ |a,b| a <=> b }
    dirs.each do |f|

      if( f =~ regex )
        part = f.match(regex)
        dir << "#{part['service']}".strip
      end
    end

    intersect = dir & services

     @log.debug( " templates: #{dirs}" )
     @log.debug( " services : #{services}" )
     @log.debug( " use      : #{intersect}" )

    intersect.each do |service|

      service  = self.removePostfix( service )
      template = Dir.glob( sprintf( '%s/overview/**%s.tpl', @templateDirectory, service ) ).first

      if( File.exist?( template ) )

        tpl = File.read( template )
        rows << tpl
      end
    end

    rows = rows.join(',')

    template = %(
      {
        "dashboard": {
          "id": null,
          "title": "%SHORTHOST% - Overview",
          "originalTitle": "%SHORTHOST% - Overview",
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
            "from": "now-5m",
            "to": "now"
          },
          "timepicker": {
            "refresh_intervals": [ "30s", "1m", "2m", "10m" ],
            "time_options": [ "5m", "15m" ]
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


  def generateLicenseTemplate( host, services )

    rows           = Array.new()
    contentServers = ['content-management-server', 'master-live-server', 'replication-live-server']
    intersect      = contentServers & services

#     @log.debug( " contentServers: #{contentServers}" )
#     @log.debug( " services      : #{services}" )
#     @log.debug( " use           : #{intersect}" )

    licenseHead    = sprintf( '%s/licenses/licenses-head.json' , @templateDirectory )
    licenseUntil   = sprintf( '%s/licenses/licenses-until.json', @templateDirectory )
    licensePart    = sprintf( '%s/licenses/licenses-part.json' , @templateDirectory )

    def beanAvailable?( host,service, beanKey )

      mergedHostJson = getJsonFromFile( @mergedHostFile )

      port = self.applicationPort( service )
      file = sprintf( '%s/%s/bulk_%s.result', @cacheDirectory, host, port )

      return self.supportMbean?( file, 'Server', beanKey )
    end

    intersect.each do |service|

      if( self.beanAvailable?( host, service, 'ServiceInfos' ) == true )

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

      if( File.exist?( licensePart ) )

        tpl = File.read( licensePart )

        tpl.gsub!( '%SERVICE%', normalizeService( service ) )

        if( service == 'replication-live-server' )

          tpl.gsub!( 'service_info-publisher' , 'service_info-webserver' )
          tpl.gsub!( 'Publischer', 'Webserver' )

        end

        rows << tpl
      end
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


  def generateServiceTemplate(serviceName, serviceTemplatePaths, additionalTemplatePaths)

    serviceTemplatePaths.each do |tpl|

      @log.debug("Creating dashboard #{File.basename(tpl).strip}")

      templateFile = File.read(tpl)
      templateJson = JSON.parse(templateFile)

      if (templateJson['dashboard'] and templateJson['dashboard']['rows'])
        rows = templateJson["dashboard"]["rows"]

        additionalTemplatePaths.each do |additionalTemplate|

          additionalTemplateFile = File.read(additionalTemplate)
          additionalTemplateJson = JSON.parse(additionalTemplateFile)

          if (additionalTemplateJson["dashboard"]["rows"])
            templateJson["dashboard"]["rows"] = additionalTemplateJson["dashboard"]["rows"].concat(rows)
          end

        end

      end

      sendTemplateToGrafana(JSON.generate(templateJson), normalizeService(serviceName))

    end
  end


  def sendTemplateToGrafana(templateFile, serviceName = nil)

    templateFile = regenerateGrafanaTemplateIDs(templateFile)

    if (!templateFile)
      @log.debug("Cannot create dashboard, invalid json")
    end

    templateFile.gsub!( '%HOST%'     , @grafanaHostname )
    templateFile.gsub!( '%SHORTHOST%', @shortHostname )
    templateFile.gsub!( '%TAG%'      , @shortHostname )
    if (serviceName)
      templateFile.gsub!( '%SERVICE%'  , serviceName )
    end

    grafanaDbUri = URI( sprintf( '%s/api/dashboards/db', @grafanaURI ) )

    response = nil
    Net::HTTP.start(grafanaDbUri.host, grafanaDbUri.port) do |http|
      request = Net::HTTP::Post.new grafanaDbUri.request_uri
      request.add_field('Content-Type', 'application/json')
      request.basic_auth 'admin', 'admin'
      request.body = templateFile
      response     = http.request request
      @log.debug("Created dashboard, ok: #{response.code}")
    end
  end


  def getJsonFromFile(filename)

    file = nil

    for y in 1..5
      if( File.exist?( filename ) )
        file = File.read( filename )
        break
      end

      sleep( 5 )
      @log.debug("Waiting for file #{filename} ... #{y}")
    end

    if( !file )
      @log.error(sprintf('File %s not found!', filename))
      return nil
    end

    begin
      json = JSON.parse(file)
    rescue JSON::ParserError => e
      @log.error('wrong result (no json)')
      @log.error(e)
      exit 1
    end

    return json
  end

end

