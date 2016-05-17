#
# lib/jenkins.rb
# Library for Dashing Job to poll Jenkins Nodes
#
# Version 2.1
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
    @log.level = Logger::DEBUG
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

    url = "#{jenkings_server}/job/#{build_id}/api/json?tree=color,builds[status,timestamp,id,result,duration,url,fullDisplayName]"

    build_info         = dataFromUrl( URI.encode( url ) )

    if( build_info == nil )

      @log.error( sprintf( 'no valid result from URI \'%s\'', url ) )

      return {
        name:     "",
        status:   'Failed',
        duration: "",
        link:     "",
        health:   "",
        time:     ""
      }
    end

    color              = build_info['color']
    bi                 = build_info['builds']

    unless !bi.nil?
      bi                    = {}
      bi['status']          = "FAILURE"
      bi["duration"]        = 0
      bi["fullDisplayName"] = ""
      bi["id"]              = "0"
      bi["result"]          = {}
      bi["timestamp"]       = 0
      bi["url"]             = ""
    end

    builds_with_status = bi.select { |i| !i['result'].nil? }

    count              = builds_with_status.count

#     @log.debug( sprintf( 'we got %d results', count ) )

    if( color == 'disabled' )
      @log.info( sprintf( 'Project %s is disabled', build_id ) )

      return {
        name:     "",
        status:   'Disabled',
        duration: "",
        link:     "",
        health:   "",
        time:     ""
      }
    end

    if( count == 0 )
      @log.error( sprintf( 'no valid result from URI \'%s\'', url ) )

      return {
        name:     "",
        status:   'Failed',
        duration: "",
        link:     "",
        health:   "",
        time:     ""
      }
    end

    successful_count   = builds_with_status.count { |i| i['result'] == 'SUCCESS' }
    latest_build       = builds_with_status.first

    @log.debug( sprintf( '  %s =>  status %s', latest_build['fullDisplayName'], latest_build['result'] ) )

    result = latest_build['result']

    if( result == 'SUCCESS' )
      status = 'Successful'
    elsif( result == 'FAILURE' )
      status = 'Failed'
    elsif( result == 'ABORTED' )
      status = 'Aborted'
    else
      status = 'Unknown'
    end

    return {
      name:      latest_build['fullDisplayName'],
      status:    status,
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

          if( job_description.to_s.strip.length == 0 )

            @log.error( 'Job Description not found' )
            next
          end

          @log.debug( sprintf( '  %s => %s', srv_description, job_description ) )

          tag    = sprintf( "%s#%s", srv_description, job_description )
          result = jenkinsBuildHealth( srv, job )

          data << {
            tag: tag,
            srv: srv,
            descr: srv_description,
            result: result
          }

        end

        @log.debug( '--------------------------------------------------------' )
      end

    end

    data.sort! { |a,b| a[:srv].to_s <=> b[:srv].to_s }
    data.uniq! { |d| d[:tag] }

    return data

  end

  # reorganize Data Struct
  # from   { :tag => $TAG, :srv => $SERVER, :result => { ... } }
  # to     { :srv => $SERVER , :result => { ... } }
  def reorganizeData( data = nil )

    if( data == nil )
      data = self.singleData
    end

    result      = Array.new
    latest      = []

    state_class = 'status-ok'
    state_msg   = ''

    data.each do |c|

      srv         = c[:srv]
      descr       = c[:descr]
      result      = c[:result]
      name        = result[:name]
      link        = result[:link]
      status      = result[:status]
      duration    = result[:duration]
      health      = result[:health]
      time        = result[:time]

      if( name.to_s.strip.length == 0 )
        next
      end

      link        = sprintf( '<a href="%s" target="_self" title="%s">%s</a>', link , name, name )

      if( status.downcase == 'successful' )
        state_class = 'status-ok'

        # filter all successful nodes
        if ( @config["jenkins"]['filterSuccessful'] == true )
          next
        end
      elsif( status.downcase == 'failed' )
        state_class = 'status-critical'
      elsif( status.downcase == 'aborted' )
        state_class = 'status-warning'
      elsif( status.downcase == 'unknown' )
        state_class = 'status-warning'
      elsif( status.downcase == 'disabled' )
        state_class = 'status-disabled'
      end

      if( health.to_int >= 80 )
        image = 'health-80plus.svg'
      elsif( health.to_int >= 60 )
        image = 'health-60to79.svg'
      elsif( health.to_int >= 40 )
        image = 'health-40to59.svg'
      elsif( health.to_int >= 20 )
        image = 'health-20to39.svg'
      else
        image = 'health-00to19.svg'
      end

      image = sprintf( '<img src="assets/%s" title="%s%% builds passed">', image, health.to_int )

      latest.push(
        { cols: [
          { value: descr   , class: 'description' },
          { value: link    , class: 'hostname'    },
          { value: image                          },
          { value: status  , class: state_class   },
        ] }
      )
    end

    result = latest

    return result

  end

end

