
require 'yaml'


SUCCESS = 'Successful'
FAILED = 'Failed'


config_file = File.dirname(File.expand_path(__FILE__)) + '/../config/jenkins.yml'
config = YAML::load(File.open(config_file))


# puts config.inspect

unless config["jenkins"].nil?

#   config["jenkins"].each do |k,v|
#
# #     puts k.to_s
# #     puts v.to_s
#
#     if v.is_a?(Array)
#       puts "is array"
#     elsif v.is_a?(Hash)
#       puts "is hash"
#
#       v.each do |key, array|
#         puts "#{key}-----"
#         puts array
#       end
#     else
#       puts("k is #{k}, value is #{v}")
#     end
#   end
#   server_name = config["icinga2"]["server"]["name"]
#   server_port = config["icinga2"]["server"]["port"]
#   api_user = config["icinga2"]["api"]["user"]
#   api_pass = config["icinga2"]["api"]["password"]
#
#   puts "server: " + server_name.to_s
#   puts "port  : " + server_port.to_s
#   puts "user  : " + api_user.to_s
#   puts "pass  : " + api_pass.to_s
else
  puts "no valid configuration found"
  exit
end



def get_url(url, auth = nil)

#  puts " url : " + url.to_s
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  request = Net::HTTP::Get.new(uri.request_uri)

  if auth != nil then
    request.basic_auth *auth
  end

  response = http.request(request)
  return JSON.parse(response.body)
end

def calculate_health(successful_count, count)
  return (successful_count / count.to_f * 100).round
end

def get_jenkins_build_health( jenkings_server, build_id )

  url = "#{jenkings_server}/job/#{build_id}/api/json?tree=builds[status,timestamp,id,result,duration,url,fullDisplayName]"

#   puts " url : " + url.to_s

  build_info         = get_url URI.encode( url )

  bi                 = build_info['builds']

  unless !bi.nil?

    bi       = {}
    bi["duration"]        = 0
    bi["fullDisplayName"] = ""
    bi["id"]              = "0"
    bi["result"]          = "FAILURE"
    bi["timestamp"]       = 0
    bi["url"]             = ""
  end

  builds_with_status = bi.select { |i| !i['result'].nil? }
  successful_count   = builds_with_status.count { |i| i['result'] == 'SUCCESS' }
  latest_build       = builds_with_status.first

#    puts " -> build with status "
#    puts builds_with_status
    puts " -> successful count  " + successful_count.to_s
    puts " -> latest build      " + latest_build.to_s

  return {
    name: latest_build['fullDisplayName'],
    status: latest_build['result'] == 'SUCCESS' ? SUCCESS : FAILED,
    duration: latest_build['duration'] / 1000,
    link: latest_build['url'],
    health: calculate_health(successful_count, builds_with_status.count),
    time: latest_build['timestamp']
  }

end






SCHEDULER.every '20s' do

  config["jenkins"].each do |server, builds|

    if builds.is_a?(Hash)
#       puts "is hash"

      builds.each do |key, array|
#         puts "  - #{key} -----"

        array.each do |build_id|

#          puts build_id
          send_event(sprintf( "%s/%s", key, build_id ), get_jenkins_build_health( key, build_id ) )

        end
      end
    end
  end


  puts "."

end
