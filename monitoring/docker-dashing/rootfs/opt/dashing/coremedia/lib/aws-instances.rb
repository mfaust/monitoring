#
# lib/aws-instances.rb

# ----------------------------------------------------------------------------

require 'aws-sdk'
require 'logger'
require 'time'

# ----------------------------------------------------------------------------

class AwsInstances

  def initialize( key_id, access_key )

    file = File.open( '/tmp/dashing-aws-instances.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    if( !key_id and !access_key )
      @log.error( 'No AWS access data given' )
    end

    @access_key    = key_id
    @secret_access = access_key
    @cCache        = {}
    @regionArray   = [ 'eu-west-1', 'us-east-1', 'us-west-1', 'eu-central-1' ]
  end

  def instances()

    metric_data = Array.new

    @regionArray.each do |region|

      @log.debug( sprintf( 'get information from region \'%s\'', region ) )

      c = @cCache[region]

      if not c
        c = @cCache[region] = Aws::EC2::Client.new({
          region: region,
          access_key_id: @access_key,
          secret_access_key: @secret_access
        })
      end

      iname       = nil
      iid         = nil
      state       = nil
      launch_time = nil

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

    end

    metric_data.sort! { |a, b| [a['region'], a['name']] <=> [b['region'], b['name']] }

    @log.debug( metric_data )

    return metric_data

  end

end

# EOF