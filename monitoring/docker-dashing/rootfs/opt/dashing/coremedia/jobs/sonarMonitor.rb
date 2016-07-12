


require './lib/sonar'

s = Sonar.new( 'config/sonar.json' )

s.run()


SCHEDULER.every '3m', :first_in => 0 do

#  fromDate = Time.now - (months * secInMonth)
  puts ' . '



end



exit 0

#require 'time'
#require 'httparty'
#require 'json'


def oldFunctions
# Constants
  secInMonth = 60 * 60 * 24 * 30
  config_path = File.expand_path(File.join(File.dirname(__FILE__), "sonarMonitor.cfg"))


# Functions
  def GetMetricInfo(server, metric)
    metricInfoService = "#{server}/api/metrics/#{metric}"
    metricInfoResponse = JSON.parse(HTTParty.get(metricInfoService).body)[0]
  end

  def GetMetrics(server, key,metricsToGet)
    metricsService = "#{server}/api/resources?resource=#{key}&metrics=#{metricsToGet.join(',')}"
    metricsResponse = JSON.parse(HTTParty.get(metricsService).body)
  end

  def GetTimemachine(server, key, metricsToGet, fromdate)
    timemachineService = "#{server}/api/timemachine?resource=#{key}&metrics=#{metricsToGet}&fromDateTime=#{fromdate}"
    timemachineResponse = JSON.parse(HTTParty.get(timemachineService).body)
  end


# Configuration
  configuration = Hash[File.read(config_path).scan(/(\S+)\s*=\s*"([^"]+)/)]
    server = "#{configuration['server']}".strip
    key = "#{configuration['key']}".strip
    id = "#{configuration['id']}".strip
    metrics = "#{configuration['metrics']}".strip
    samples = "#{configuration['samples']}".strip.to_i
    months = "#{configuration['months']}".strip.to_i
    interval = "#{configuration['interval']}".strip

# Initialization
  mArray = Array.new
  mLabels = Hash.new
  mDescriptions = Hash.new
  currVal = Hash.new

  metrics.split(",").each do |m|
    mInfo = GetMetricInfo(server, m)

    mLabels[m] = mInfo["name"]
    mDescriptions[m] = mInfo["description"]
    currVal[m] = 0
  end
  values = Hash.new
  normalizedValues = Hash.new
  dates = Hash.new

end







#---------------#
#--- MONITOR ---#
#---------------#
SCHEDULER.every interval, :first_in => 0 do |job|
  # Initialization
  fromDate = Time.now - (months * secInMonth)
  metrics.split(",").each do |m|
    values[m] = []
    normalizedValues[m] = []
    dates[m] = []
  end

  # Call api
  result = GetTimemachine(server, key, metrics, fromDate.utc.iso8601);

  # Parse results
  cols = result[0]["cols"]
  cells = result[0]["cells"]

  (0..cols.count-1).each do |m|
    minVal = maxVal = cells[0]["v"][m]
    metric = cols[m]["metric"]
    (0..samples).each do |i|
      value = cells[i]["v"][m]
      if(value < minVal)
        minVal = value
      end
      if(value > maxVal)
        maxVal = value
      end
      values[metric] << value
      dates[metric] << cells[i]["d"]
    end
    currVal[metric] = cells[samples]["v"][m]
    minVal = minVal - (minVal * 0.1)
    maxVal = maxVal + (maxVal * 0.1)

    # Normalize values for charting
    (0..samples).each do |i|
      normalizedValues[metric][i] = values[metric][i] - minVal
    end

    # Push to dashboard
    send_event(id+metric,
      metric: mLabels[metric],
      description: mDescriptions[metric],
      current:currVal[metric],
      values:values[metric],
      normalized:normalizedValues[metric],
      tooltips:dates[metric],
      samples:samples)
#   items.push({divclass: "metric "+m.to_s, metric: mlabels[metric], values:values[metric]})
  end
# puts items
# send_event(id, { items:items })
end
