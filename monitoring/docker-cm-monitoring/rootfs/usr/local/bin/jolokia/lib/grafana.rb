# require './lib/grafana/client.rb'


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

require_relative 'tools'

# -------------------------------------------------------------------------------------------------------------------

class Grafana

  def initialize( settings = {} )

    @logDirectory   = settings['log_dir']      ? settings['log_dir']      : '/tmp'
    @cacheDirectory = settings['cache_dir']    ? settings['cache_dir']    : '/var/tmp/monitoring'
    @grafanaHost    = settings['grafana_host'] ? settings['grafana_host'] : 'localhost'
    @grafanaPort    = settings['grafana_port'] ? settings['grafana_port'] : 3000
    @grafanaPath    = settings['grafana_path'] ? settings['grafana_path'] : nil

    @grafanaURI     = sprintf( 'http://%s:%s/%s', @grafanaHost, @grafanaPort, @grafanaPath )

    logFile = sprintf( '%s/grafana.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end


  end

  # add dashboards for a host
  def addDashbards(host, recreate = false)

    if recreate
      deleteDashboards(host)
    end

    #TODO tmp and template dir as global var
    tmp_dir = "/tmp"
    tpl_dir = "../../share/templates/grafana"
    FileUtils.mkdir_p("#{tmp_dir}/grafana")

    short_hostname = host.split(".").first
    grafana_hostname = host.gsub(".", "-")

    templates = Dir["#{tpl_dir}/cm*.json"]

    @log.debug("Found Templates: #{templates}")

    # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
    uri = URI( sprintf( '%s/api/dashboards/db', @grafanaURI ) ) #  "http://localhost/grafana/api/dashboards/db")
    @log.debug("Grafana Uri: #{uri}")

    templates.each do |tpl|

      tpl_basename = File.basename(tpl).strip

      @log.debug("Creating dashboard #{tpl_basename} for host #{host}")

      FileUtils.cp(tpl, "#{tmp_dir}/grafana/#{tpl_basename}")

      tpl_file = File.read("#{tmp_dir}/grafana/#{tpl_basename}")

      tpl_file.gsub! '%HOST%', grafana_hostname
      tpl_file.gsub! '%SHORTHOST%', short_hostname
      tpl_file.gsub! '%TAG%', short_hostname

      res = nil
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Post.new uri.request_uri
        request.add_field('Content-Type', 'application/json')
        request.basic_auth 'admin', 'admin'
        request.body = tpl_file
        res = http.request request
        @log.debug("Created dashboard #{tpl_basename} for host #{host}, ok: #{res.code}")
      end

    end
  end

  # delete the dashboards for a host
  def deleteDashboards(host)

    @log.debug("Deleting dashboards for host #{host}")

    # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
    uri = URI( sprintf( '%s/api/search?query=&tag=%s', @grafanaURI, host ) ) #"http://localhost/grafana/api/search?query=&tag=#{host}")
    @log.debug("Grafana Uri: #{uri}")

    res = nil
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri
      request.basic_auth 'admin', 'admin'
      res = http.request request
      @log.debug("Get dashboards for host #{host} ok: #{res.code}")
    end

    if res.code != "200"
      @log.debug("No dashboards found to delete")
      return
    end

    resp_body = JSON.parse(res.body)
    dashboards = resp_body.collect { |item| item['uri'] }
    @log.debug("Deleting Grafana Dashboards: #{dashboards}")

    dashboards.each do |i|
      # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
      uri = URI( sprintf( '%s/api/dashboards/%s', @grafanaURI, i ) ) #  "http://localhost/grafana/api/dashboards/#{i}")
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Delete.new(uri.path)
        request.basic_auth 'admin', 'admin'
        res = http.request request
        @log.debug("Deleted Dashboard #{i}, ok: #{res.code}")
      end
    end
  end
end

