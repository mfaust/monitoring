#
# lib/jenkins.rb
# Library for Dashing Job to poll Jenkins Nodes
#
# Version 2.0
#
# (c) 2016 Coremedia - Bodo Schulz <bodo.schulz@coremedia.com>

# ----------------------------------------------------------------------------

require 'yaml'
require 'json'
require 'uri'
require 'net/http'
require 'openssl'
require 'logger'

# ----------------------------------------------------------------------------

class Jenkins

  def initialize( config_file )

    file = File.open( '/tmp/dashing-jenkins.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    config_file = File.expand_path( config_file )

    begin

      if( File.exist?( config_file ) )

        file = File.read( config_file )

        @config      = JSON.parse( file )
      else
        @log.error( sprintf( 'Config File %s not found!', config_file ) )
        exit 1
      end

    rescue JSON::ParserError => e

      @log.error( 'wrong result (no json)')
      @log.error( e )
      exit 1
    end

  end

  def dataFromUrl( url, auth = nil )

    uri  = URI.parse( url )
    http = Net::HTTP.new( uri.host, uri.port )

    if( uri.scheme == 'https' )
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new( uri.request_uri )

    if( auth != nil )
      request.basic_auth *auth
    end

    response = http.request( request )

    begin
      data = JSON.parse( response.body )
      return data
    rescue JSON::ParserError => e

      @log.error( sprintf( 'url : %s', url ) )
      @log.error( 'wrong result (no json)')

      return nil
    end

  end

  def calculateHealth( successful_count, count )

    return ( successful_count / count.to_f * 100 ).round

  end

  def jenkinsBuildHealth( jenkings_server, build_id )

    url = "#{jenkings_server}/job/#{build_id}/api/json?tree=builds[status,timestamp,id,result,duration,url,fullDisplayName]"

    build_info         = dataFromUrl( URI.encode( url ) )

    if( build_info == nil )

      return {
        name:     "",
        status:   'Failed',
        duration: "",
        link:     "",
        health:   "",
        time:     ""
      }
    end

    bi                 = build_info['builds']

    unless !bi.nil?
      bi       = {}
      bi["duration"]        = 0
      bi["fullDisplayName"] = ""
      bi["id"]              = "0"
      bi["result"]          = "FAILURE"
      bi["timestamp"]       = 0
      bi["url"]             = ""
    end

    builds_with_status = bi.select { |i| !i['result'].nil? }
    successful_count   = builds_with_status.count { |i| i['result'] == 'SUCCESS' }
    latest_build       = builds_with_status.first

    return {
      name:      latest_build['fullDisplayName'],
      status:    latest_build['result'] == 'SUCCESS' ? 'Successful' : 'Failed',
      duration:  latest_build['duration'] / 1000,
      link:      latest_build['url'],
      health:    calculateHealth( successful_count, builds_with_status.count ),
      time:      latest_build['timestamp']
    }

  end

  def singleData

    data = Array.new

    @config["jenkins"].each do

      rootNode = @config['jenkins']
      servers  = @config['jenkins']['server']

      servers.each do |srv,c|

        @log.debug( '--------------------------------------------------------' )
        srv_description = c['description']
        jobs            = c['jobs']

        @log.debug( sprintf( 'Jenkins Server \'%s\' (%s)', srv_description, srv ) )

        jobs.each do |j|

          job             = nil
          job_description = nil

          if j.is_a?(Hash)

            j.each do |k, v|

              job             = k
              job_description = v['description'].nil? ? job : v['description']

            end
          else
            job             = j
            job_description = job

          end

          @log.debug( sprintf( '  %s => %s', srv_description, job_description ) )

          tag    = sprintf( "%s#%s", srv_description, job_description )
          result = jenkinsBuildHealth( srv, job )

          data << {
            tag: tag,
            srv: srv,
            result: result
          }

        end

        @log.debug( '--------------------------------------------------------' )
      end

    end

    return data

  end

end

