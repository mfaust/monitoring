# lib/cloudwatch.rb

require 'aws-sdk'
require 'logger'
require 'time'

class Cloudwatch

  def initialize(options)

    file = File.open( '/tmp/dashing-cloudwatch.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @access_key_id     = options[:access_key_id]
    @secret_access_key = options[:secret_access_key]
    @clientCache       = {}
  end

  def get_metric_data(region, namespace, dimensions,  metric_name, type=:average, options={})

    if type == :average
      statName = "Average"
    elsif type == :sum
      statName = "Sum"
    elsif type == :maximum
      statName = "Maximum"
    end
    statKey = type

    # Get an API client instance
    cw2 = @clientCache[region]
    if not cw2
      cw2 = @clientCache[region] = Aws::CloudWatch::Client.new({
        region: region,
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key
      })
    end

    # Build a default set of options to pass to get_metric_statistics
    duration   = (options[:duration]   or (60*60*4))
    start_time = (options[:start_time] or (Time.now - duration))
    end_time   = (options[:end_time]   or (Time.now))

    get_metric_statistics_options = {
        namespace: namespace ,
        metric_name: metric_name,
        statistics: [statName],
        start_time: start_time.utc.iso8601,
        end_time: end_time.utc.iso8601,
        period: (options[:period] or (60 * 5)), # Default to 5 min stats
        dimensions: dimensions
    }

    # Go get stats
    result = cw2.get_metric_statistics(get_metric_statistics_options)

    if ((not result[:datapoints]) or (result[:datapoints].length == 0))
      # TODO: What kind of errors can I get back?
      @log.warning( sprintf( 'Warning: Got back no data for metric \'%s\'', metric_name ) )
#      puts "\e[33mWarning: Got back no data for metric #{metric_name}\e[0m"
      answer = nil
    else
      # Turn the result into a Rickshaw-style series
      data = []

      result[:datapoints].each do |datapoint|
        point = {
          x: (datapoint[:timestamp].to_i), # time in seconds since epoch
          y: datapoint[statKey]
        }
        data.push point
      end
      data.sort! { |a,b| a[:x] <=> b[:x] }

      answer = {
        name: metric_name,
        data: data
      }
    end

    return answer
  end

  def get_last_metric_data(region, namespace, dimensions,  metric_name, type=:average, options={})

    if type == :average
      statName = "Average"
    elsif type == :sum
      statName = "Sum"
    elsif type == :maximum
      statName = "Maximum"
    end

    statKey = type

    # Get an API client instance
    cw2 = @clientCache[region]
    if not cw2
        cw2 = @clientCache[region] = Aws::CloudWatch::Client.new({
            region: region,
            access_key_id: @access_key_id,
            secret_access_key: @secret_access_key
        })
    end

    # Build a default set of options to pass to get_metric_statistics
    duration   = (options[:duration]   or (60*60*1))
    start_time = (options[:start_time] or (Time.now - duration))
    end_time   = (options[:end_time]   or (Time.now))

    get_metric_statistics_options = {
        namespace: namespace ,
        metric_name: metric_name,
        statistics: [statName],
        start_time: start_time.utc.iso8601,
        end_time: end_time.utc.iso8601,
        period: (options[:period] or (60 * 5)), # Default to 5 min stats
        dimensions: dimensions
    }

    # Go get stats
    result = cw2.get_metric_statistics(get_metric_statistics_options)

    if ((not result[:datapoints]) or (result[:datapoints].length == 0))
        # TODO: What kind of errors can I get back?
        @log.warning( sprintf( 'Warning: Got back no data for metric \'%s\'', metric_name ) )
#        puts "\e[33mWarning: Got back no data for metric #{metric_name}\e[0m"
        answer = nil
    else

      data = []

      result[:datapoints].sort!{|a,b| a[:timestamp] <=> b[:timestamp]}

      last = result[:datapoints].last
      time = last[:timestamp].strftime('%d.%m.%Y %H:%M')
      avg  = sprintf("%#.2f", last[:average] )

      if( avg.to_i > 15 )
        color = 'red'
      elsif( avg.to_i < 15 and avg.to_i > 8 )
        color = 'yellow'
      else
        color = 'green'
      end

      answer = {
        name: metric_name,
        date: time,
        avg:  avg,
        state: color
      }
    end

    return answer

  end
end
