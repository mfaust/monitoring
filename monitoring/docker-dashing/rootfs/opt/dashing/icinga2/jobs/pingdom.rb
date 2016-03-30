#

require 'pingdom-faraday'

api_key  = ENV['PINGDOM_API']  || ''
user     = ENV['PINGDOM_USER'] || ''
password = ENV['PINGDOM_PASS'] || ''

if api_key.empty? or user.empty? or password.empty?
  puts " => pingdom Job"
  puts " [E] no valid configuration found!"

else

  SCHEDULER.every '5m', :first_in => 0 do

    client = Pingdom::Client.new :username => user, :password => password, :key => api_key

    if client.checks

      checks = client.checks.map { |check|

        if check.status == 'up'
          color = 'green'
        else
          color = 'red'
        end

        last_response = check.last_response_time.to_s + " ms"

        {
          name: check.name,
          state: color,
          lastRepsonseTime: last_response
        }
      }

      checks.sort_by { |check| check['name'] }

      send_event('pingdom', { checks: checks })
    end
  end

end