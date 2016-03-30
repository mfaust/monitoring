# cloud Formation

require 'aws-sdk'

access_key     = ENV['AWS_ACCESS_KEY_ID']     || ''
secret_access  = ENV['AWS_SECRET_ACCESS_KEY'] || ''

if access_key.empty? or secret_access.empty?
  puts " => cloudformation Job"
  puts " [E] no valid configuration found!"
else

  SCHEDULER.every '1m', :first_in => 0 do

    Aws.config.update({
      region: 'eu-west-1',
      credentials: Aws::Credentials.new( access_key, secret_access )
    })

    cloudformation = Aws::CloudFormation::Client.new

    resp = cloudformation.list_stacks({
      stack_status_filter: [
        'CREATE_IN_PROGRESS', 'CREATE_FAILED', 'CREATE_COMPLETE'
      ]
#        'ROLLBACK_IN_PROGRESS', 'ROLLBACK_FAILED', 'ROLLBACK_COMPLETE',
#        'DELETE_IN_PROGRESS', 'DELETE_FAILED', 'DELETE_COMPLETE',
#        'UPDATE_IN_PROGRESS', 'UPDATE_ROLLBACK_COMPLETE'
#      ]
    })

#    with_status_CREATE_COMPLETE = resp.stack_summaries.select { |i| i['stack_status'] == 'CREATE_COMPLETE' }
#    with_status_CREATE_FAILED   = resp.stack_summaries.select { |i| i['stack_status'] == 'CREATE_FAILED' }

#    with_status_CREATE_COMPLETE.sort_by { |check| check['creation_time'] }
#    with_status_CREATE_FAILED.sort_by { |check| check['creation_time'] }

    with_status_CREATE = resp.stack_summaries.sort_by { |check| check['creation_time'] }

    results = with_status_CREATE.map { |check|

      if check.stack_status == 'CREATE_FAILED'
        color = 'red'
      else
        color = 'green'
      end

      {
        name: check.stack_name.to_s,
        state: color,
        creationTime: check.creation_time.strftime('%d.%m.%Y'),
      }
    }
    send_event( 'cloudformation', { cfchecks: results } )

  end

end
