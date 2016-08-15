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

    @grafanaHost    = settings['grafana_host'] ? settings['grafana_host'] : 'localhost'
    @grafanaPort    = settings['grafana_port'] ? settings['grafana_port'] : 3000
    @grafanaPath    = settings['grafana_path'] ? settings['grafana_path'] : nil

    @grafanaURI     = sprintf( 'http://%s:%s%s', @grafanaHost, @grafanaPort, @grafanaPath )

    logFile = sprintf( '%s/grafana.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    #TODO tmp and template dir as global var
#     @tmp_dir = "/tmp"
#     FileUtils.mkdir_p("#{@tmp_dir}/grafana")

  end


  # add dashboards for a host
  def addDashbards(host, recreate = false)

    @log.debug("Adding dashboards for host #{host}, recreate: #{recreate}")

    if recreate
      deleteDashboards(host)
    end

    if( ! isIp?( host ) )
      @shortHostname   = host.split( '.' ).first
    else
      @shortHostname   = host
    end

    @grafanaHostname = host.gsub( '.', '-' )
    discovery_file   = sprintf( '%s/%s/discovery.json'     , @cacheDirectory, host )
    merged_host_file = sprintf( '%s/%s/mergedHostData.json', @cacheDirectory, host )

    # determine services from discovery.json file, e.g. cae-live, master-live-server, caefeeder-live
    discovery_json = getJsonFromFile( discovery_file )

    if( discovery_json != nil )

      services       = discovery_json.keys

      # determine type of service from mergedHostData.json file, e.g. cae, caefeeder, contentserver
      merged_host_json = getJsonFromFile(merged_host_file)

      @log.debug("Found services: #{services}")

      template_paths = Array.new
      aggregation_map = Hash.new

      services.each do |service|
        paths = Array.new
        @log.debug("Searching templates paths for service: #{service}")

        # cae-live-1 -> cae-live
        service_name = removePostfix(service)

        # get templates for service
        paths.push(*getTemplatePathsForService(service_name))

        # get templates for service type
        service_type = merged_host_json[service]["application"]
        if service_type
          paths.push(*getTemplatePathsForServiceType(service_type))
        end

        template_paths.push(*paths)

        if( service_type && isAggregationTemplateAvailable(service_type) )
          if( !aggregation_map[service_type] )
            aggregation_map[service_type] = Array.new
          end

          aggregation_map[service_type].push(*paths)
        end

      end

      @log.debug( "Found Template paths: #{template_paths} and aggregation template paths #{aggregation_map}" )

      generateAggregatedTemplates( aggregation_map )
      generateServiceTemplates( template_paths )
    end
  end


  # delete the dashboards for a host
  def deleteDashboards( host )

    @log.debug("Deleting dashboards for host #{host}")
#
#     # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
#     uri = URI( sprintf( '%s/api/search?query=&tag=%s', @grafanaURI, host ) ) #"http://localhost/grafana/api/search?query=&tag=#{host}")
#     @log.debug("Grafana Uri: #{uri}")
#
#     response = nil
#     Net::HTTP.start(uri.host, uri.port) do |http|
#       request = Net::HTTP::Get.new uri.request_uri
#       request.basic_auth 'admin', 'admin'
#       response = http.request request
#       @log.debug("Get dashboards for host #{host} ok: #{response.code}")
#     end
#
#     if response.code != "200"
#       @log.debug("No dashboards found to delete")
#       return
#     end
#
#     resp_body = JSON.parse(response.body)
#     dashboards = resp_body.collect { |item| item['uri'] }

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
    if service =~ /\d/
      last_part = service.split("-").last
      service = service.chomp("-#{last_part}")
      @log.debug("Chomped service: #{service}")
    end
    return service
  end


  def getTemplatePathsForServiceType(service_type)

    paths = Array.new()
#    @log.debug(service_type)
    dirs  = Dir["#{@templateDirectory}/service-types/#{service_type}"]
    count = dirs.count()

    if( count != 0 )
      @log.debug("Found dirs: #{dirs}")
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
      @log.debug("Found dirs: #{dirs}")
      dirs.each do |dir|
        paths.push(*Dir["#{dir}/cm*.json"])
      end
    end

    return paths
  end


  def isAggregationTemplateAvailable( service_type )

    baseFile = Dir["#{@templateDirectory}/service-types/#{service_type}/aggregate*.json"]
    count    = baseFile.count()

    if( count != 0 )

      @log.debug("Found aggregation file #{baseFile}")

#       if( baseFile.length > 0 )
        return true
#       end
    end

    return false
  end


  def generateAggregatedTemplates(aggregated_templates)

    aggregated_templates.each do |service_type, fragments|

      @log.debug("Aggregating templates for '#{service_type}' with #{fragments}")

      tpl_basename = service_type

      @log.debug("Creating dashboard '#{tpl_basename}'")

      aggregation_file = Dir["#{@templateDirectory}/service-types/#{service_type}/aggregate*.json"]

      if( aggregation_file.length > 0 )

        aggregation_file_json = getJsonFromFile(aggregation_file[0])

        fragments.each do |fragment|
          fragment_file = File.read(fragment)
          fragment_json = JSON.parse(fragment_file)
          fragment_json["dashboard"]["rows"].each do |item|
            aggregation_file_json["dashboard"]["rows"] << item
          end
        end
        merged_template = JSON.generate(aggregation_file_json)
      end

      sendTemplateToGrafana( merged_template )

    end
  end


  def generateServiceTemplates(templates)
    templates.each do |tpl|

      @log.debug("Creating dashboard #{File.basename(tpl).strip}")

      tpl_file = File.read(tpl)

      sendTemplateToGrafana(tpl_file)

    end
  end


  def sendTemplateToGrafana(tpl_file)
    tpl_file.gsub! '%HOST%', @grafanaHostname
    tpl_file.gsub! '%SHORTHOST%', @shortHostname
    tpl_file.gsub! '%TAG%', @shortHostname

    grafana_db_uri = URI( sprintf( '%s/api/dashboards/db', @grafanaURI ) )

    response = nil
    Net::HTTP.start(grafana_db_uri.host, grafana_db_uri.port) do |http|
      request = Net::HTTP::Post.new grafana_db_uri.request_uri
      request.add_field('Content-Type', 'application/json')
      request.basic_auth 'admin', 'admin'
      request.body = tpl_file
      response = http.request request
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

