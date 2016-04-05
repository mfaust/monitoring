# jobs/some_job.rb


require './lib/cloudwatch'

access_key     = ENV['AWS_ACCESS_KEY_ID']     || ''
secret_access  = ENV['AWS_SECRET_ACCESS_KEY'] || ''
region         = ENV['AWS_REGION']            || 'eu-west-1'

if access_key.empty? or secret_access.empty?
  puts " => cloudformation Job"
  puts " [E] no valid configuration found!"
else

  cw = Cloudwatch.new({
    :access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
  })
end

@cCache = {}

SCHEDULER.every '2m', :first_in => 0 do |job|

  c = @cCache[region]

  if not c
    c = @cCache[region] = Aws::EC2::Client.new({
      region: region,
      access_key_id: access_key,
      secret_access_key: secret_access
    })
  end

  iname       = nil
  iid         = nil
  state       = nil
  launch_time = nil
  metric_data = Array.new

  # get all described EC2 Instances
  c.describe_instances.each  do |instance|

    instance.reservations.each do |r|

      r.instances.each do |i|

        iname       = nil
        iid         = i.instance_id
        state       = i.state.name
        launch_time = i.launch_time
         if !i.tags.nil?
           i.tags.each do |t|
             if t.key == 'Name'
               iname = t.value
             end
           end
         end
      end

      metric_data << {
        name: iname, namespace: 'AWS/EC2', region: region , metric: 'CPUUtilization', type: :average, dimensions: [ { name: 'InstanceId', value: iid } ]
      }
    end
  end

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
