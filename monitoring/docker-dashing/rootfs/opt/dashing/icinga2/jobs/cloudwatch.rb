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

SCHEDULER.every '4m', :first_in => 0 do |job|

  elb_latencies = Array.new

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

  c.describe_instances.each  do |instance|

    instance.reservations.each do |r|

      if !r.instances.nil?
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
      end

      elb_latencies << {
        name: iname, namespace: 'AWS/EC2', region: region , metric: 'CPUUtilization', type: :average, dimensions: [ { name: 'InstanceId', value: iid } ]
      }
    end
  end

  elb_series = []

  elb_latencies.each do |item|
    elb_data = cw.get_metric_data(item[:region], item[:namespace], item[:dimensions], item[:metric], item[:type], {})
    elb_data[:name] = item[:name]
    elb_series.push elb_data
  end

  send_event "cw-elb", { series: elb_series }

end
