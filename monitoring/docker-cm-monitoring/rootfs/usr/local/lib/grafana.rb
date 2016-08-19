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
# require 'resolv-replace.rb'
require 'net/http'
require 'uri'

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

#     include Grafana::DashboardTemplate

    #TODO tmp and template dir as global var
#     @tmp_dir = "/tmp"
#     FileUtils.mkdir_p("#{@tmp_dir}/grafana")

  end


  def shortHostname( hostname )

    if( ! isIp?( hostname ) )
      shortHostname   = hostname.split( '.' ).first
    else
      shortHostname   = hostname
    end

    return shortHostname

  end

  # add dashboards for a host
  def addDashbards(host, recreate = false)

    @log.debug("Adding dashboards for host #{host}, recreate: #{recreate}")

    if recreate
      deleteDashboards(host)
    end

    @shortHostname   = self.shortHostname( host )
    @grafanaHostname = host.gsub( '.', '-' )

    discoveryFile    = sprintf( '%s/%s/discovery.json'     , @cacheDirectory, host )
    mergedHostFile   = sprintf( '%s/%s/mergedHostData.json', @cacheDirectory, host )

    # determine services from discovery.json file, e.g. cae-live, master-live-server, caefeeder-live
    discoveryJson = getJsonFromFile( discoveryFile )

    if( discoveryJson != nil )

      services       = discoveryJson.keys

      self.generateOverviewTemplate( services )

      # determine type of service from mergedHostData.json file, e.g. cae, caefeeder, contentserver
      merged_host_json = getJsonFromFile(mergedHostFile)

      @log.debug("Found services: #{services}")

      templatePaths  = Array.new()
      aggregationMap = Hash.new()

      services.each do |service|

        paths = Array.new()

        @log.debug("Searching templates paths for service: #{service}")

        # cae-live-1 -> cae-live
        serviceName = removePostfix(service)

        # get templates for service
        paths.push(*getTemplatePathsForService(serviceName))

        # get templates for service type
        serviceType = merged_host_json[service]["application"]
        if serviceType
          paths.push(*getTemplatePathsForServiceType(serviceType))
        end

        templatePaths.push(*paths)

        if( serviceType && isAggregationTemplateAvailable(serviceType) )
          if( !aggregationMap[serviceType] )
            aggregationMap[serviceType] = Array.new
          end

          aggregationMap[serviceType].push(*paths)
        end

      end

      @log.debug( "Found Template paths: #{templatePaths} and aggregation template paths #{aggregationMap}" )

#      generateAggregatedTemplates( aggregationMap )
      generateServiceTemplates( templatePaths )
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


  def isAggregationTemplateAvailable( serviceType )

    baseFile = Dir["#{@templateDirectory}/service-types/#{serviceType}/aggregate*.json"]
    count    = baseFile.count()

    if( count != 0 )

      @log.debug("Found aggregation file #{baseFile}")

#       if( baseFile.length > 0 )
        return true
#       end
    end

    return false
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
          "tags": [ "%TAG%" ],
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

    # TODO
    # recreate ID's

    if( validJson?( template ) )

      # @log.debug( JSON.pretty_generate( JSON.parse( template ) ) )

      @log.debug( 'send to grafana' )
      sendTemplateToGrafana( template )
    else
      @log.debug( 'no valid JSON' )
    end

  end


  def generateAggregatedTemplates(aggregatedTemplates)

    aggregatedTemplates.each do |serviceType, fragments|

      @log.debug("Aggregating templates for '#{serviceType}' with #{fragments}")

      templateBasename = serviceType

      @log.debug("Creating dashboard '#{templateBasename}'")

      aggregationFile = Dir["#{@templateDirectory}/service-types/#{serviceType}/aggregate*.json"]

      if( aggregationFile.length > 0 )

        aggregationFileJson = getJsonFromFile(aggregationFile[0])

        fragments.each do |fragment|

          if( File.exists?( fragment ) )

            @log.error( sprintf( 'read fragment \'%s\'', fragment ) )

            fragmentFile = File.read(fragment)
            fragmentJson = JSON.parse(fragmentFile)

            if( fragmentJson['dashboard'] and fragmentJson['dashboard']['rows'] )

              if( fragmentJson["dashboard"]["rows"] )
                fragmentJson["dashboard"]["rows"].each do |item|
                  aggregationFileJson["dashboard"]["rows"] << item
                end
              end

            end

          else
            @log.error( sprintf( "File '%s' not exists", fragment ) )
          end
        end
        mergedTemplate = JSON.generate(aggregationFileJson)
      end

      sendTemplateToGrafana( mergedTemplate )

    end
  end


  def generateServiceTemplates(templates)

    templates.each do |tpl|

      @log.debug("Creating dashboard #{File.basename(tpl).strip}")

      templateFile = File.read(tpl)

      sendTemplateToGrafana(templateFile)

    end
  end


  def sendTemplateToGrafana(templateFile)

    templateFile.gsub!( '%HOST%'     , @grafanaHostname )
    templateFile.gsub!( '%SHORTHOST%', @shortHostname )
    templateFile.gsub!( '%TAG%'      , @shortHostname )

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

