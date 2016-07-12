#
# lib/sonar.rb
# Library for Dashing Job to poll Sonar
#
# Version 1.0
#
# (c) 2016 Coremedia - Bodo Schulz <bodo.schulz@coremedia.com>

# ----------------------------------------------------------------------------

require 'yaml'
require 'json'
require 'time'
require 'httparty'
#require 'uri'
#require 'net/http'
#require 'openssl'
require 'logger'

# ----------------------------------------------------------------------------

class Sonar

  def initialize( config_file )

    file = File.open( '/tmp/dashing-sonar.log', File::WRONLY | File::APPEND | File::CREAT )
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

    @secInMonth = 60 * 60 * 24 * 30
    @cfg_server = @config['sonar']['server']
    @cfg_metric = @config['sonar']['metrics']
    @cfg_key    = @config['sonar']['key']
    @cfg_months = @config['sonar']['month']



  end

  def metricInfo( server, metric )
    metricInfoService = "#{server}/api/metrics/#{metric}"

    @log.debug( sprintf( '  metricInfoService \'%s\'', metricInfoService ) )

    http = HTTParty.get( metricInfoService ).body

    @log.debug( http )

    metricInfoResponse = JSON.parse( http )[0]
  end

  def metrics( server, key, metricsToGet )
    metricsService = "#{server}/api/resources?resource=#{key}&metrics=#{metricsToGet.join(',')}"

    @log.debug( sprintf( '  metricInfoService \'%s\'', metricsService ) )

    metricsResponse = JSON.parse(HTTParty.get(metricsService).body)
  end

  def timemachine( server, key, metricsToGet, fromdate )

    timemachineService = "#{server}/api/timemachine?resource=#{key}&metrics=#{metricsToGet}&fromDateTime=#{fromdate}"

    @log.debug( sprintf( '  timemachineService \'%s\'', timemachineService ) )

    timemachineResponse = JSON.parse(HTTParty.get(timemachineService).body)
  end

  def run

#     @log.debug( sprintf( @metric ) )
#
#     # Initialization
#     mArray        = Array.new
#     mLabels       = Hash.new
#     mDescriptions = Hash.new
#     currVal       = Hash.new
#
#     @metric.split( ',' ).each do |m|
#       #mInfo            = self.metricInfo( @server, m )
#       mLabels[m]       = ''
#       mDescriptions[m] = ''
#       currVal[m]       = 0
#     end
#
    values           = Hash.new
    normalizedValues = Hash.new
    dates            = Hash.new

#     @log.debug( sprintf( @metric ) )


    fromDate = Time.now - ( @cfg_months.to_i * @secInMonth.to_i )
    @cfg_metric.split(",").each do |m|


      values[m]           = []
      normalizedValues[m] = []
      dates[m]            = []
    end

    # Call api
    result = self.timemachine( @cfg_server, @cfg_key, @cfg_metric, fromDate.utc.iso8601 );

    @log.debug( sprintf( values ) )


#     # Parse results
#     cols   = result[0]["cols"]
#     cells  = result[0]["cells"]
#
#     (0..cols.count-1).each do |m|
#
#       minVal = maxVal = cells[0]["v"][m]
#       metric = cols[m]["metric"]
#
#       (0..samples).each do |i|
#         value = cells[i]["v"][m]
#         if(value < minVal)
#           minVal = value
#         end
#         if(value > maxVal)
#           maxVal = value
#         end
#         values[metric] << value
#         dates[metric] << cells[i]["d"]
#       end
#
#       currVal[metric] = cells[samples]["v"][m]
#       minVal = minVal - (minVal * 0.1)
#       maxVal = maxVal + (maxVal * 0.1)
#
#       # Normalize values for charting
#       (0..samples).each do |i|
#         normalizedValues[metric][i] = values[metric][i] - minVal
#       end
#
#       # Push to dashboard
#       send_event(
#         id + metric,
#         metric: mLabels[metric],
#         description: mDescriptions[metric],
#         current:currVal[metric],
#         values:values[metric],
#         normalized:normalizedValues[metric],
#         tooltips:dates[metric],
#         samples:samples)
    end
  end
end

