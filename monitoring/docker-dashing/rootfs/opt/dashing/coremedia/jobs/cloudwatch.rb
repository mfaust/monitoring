#
# jobs/cloudwatch.rb

require './lib/aws-instances'
require './lib/cloudwatch'

access_key     = ENV['AWS_ACCESS_KEY_ID']     || ''
secret_access  = ENV['AWS_SECRET_ACCESS_KEY'] || ''
# region         = ENV['AWS_REGION']            || 'eu-west-1'

if access_key.empty? or secret_access.empty?
  puts " => cloudformation Job"
  puts " [E] no valid configuration found!"
else

  i  = AwsInstances.new(
    ENV['AWS_ACCESS_KEY_ID'],
    ENV['AWS_SECRET_ACCESS_KEY']
  )

  cw = Cloudwatch.new({
    :access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
  })

#   @regionArray = [ 'eu-west-1', 'us-east-1', 'us-west-1', 'eu-central-1' ]

  SCHEDULER.every '2m', :first_in => 0 do |job|

    metric_data   = i.instances()

    metrics_avg   = []
    metrics_graph = []

    metric_data.each do |item|

      data_avg        = cw.get_last_metric_data( item[:region], item[:namespace], item[:dimensions], item[:metric], item[:type], {} )
      data_avg[:name] = item[:name]
      metrics_avg.push data_avg

      data_graph        = cw.get_metric_data( item[:region], item[:namespace], item[:dimensions], item[:metric], item[:type], {} )
      data_graph[:name] = item[:name]
      metrics_graph.push data_graph
    end

    # sorting for AVG and them revert them (highest above)
    metrics_avg.sort!{ |a,b| a[:avg].to_i <=> b[:avg].to_i }.reverse!

    send_event "simple_cloudwatch", { series: metrics_avg }
    send_event "cloudwatch", { series: metrics_graph }

  end
end