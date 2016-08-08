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
require './lib/tools'

# -------------------------------------------------------------------------------------------------------------------

class Grafana

  def initialize
    file = File.open('/tmp/monitor-grafana.log', File::WRONLY | File::APPEND | File::CREAT)
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end
  end


  # delete the dashboards for a host
  def deleteDashboards(host)

    @log.debug("Deleting dashboards for host #{host}")

    # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
    uri = URI("http://localhost/grafana/api/search?query=&tag=#{host}")

    @log.debug("Grafana Uri: #{uri}")

    res = nil
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri
      request.basic_auth 'admin', 'admin'
      res = http.request request
      @log.debug("Get dashboards for host #{host} ok: #{res.code}")
    end

    resp_body = JSON.parse(res.body)
    dashboards = resp_body.collect { |item| item['uri'] }
    @log.debug("Deleting Grafana Dashboards: #{dashboards}")

    dashboards.each do |i|
      # TODO: Should be http://grafana:3000 but does not work, Error: Name or service not known
      uri = URI("http://localhost/grafana/api/dashboards/#{i}")
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Delete.new(uri.path)
        request.basic_auth 'admin', 'admin'
        res = http.request request
        @log.debug("Deleted Dashboard #{i}, ok: #{res.code}")
      end
    end
  end
end