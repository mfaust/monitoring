#!/usr/bin/env ruby

require 'net/http'
require 'open3'
require 'json'

o = []

def get_response_with_redirect(url)

  uri = URI.parse(url)

  http = Net::HTTP.new(uri.host,uri.port)
  resp, data = http.get(uri.path,nil)

  #1."Location" response redirect...
  if( resp.response['Location'] != nil )
    # puts 'Direct to: ' + resp.response['Location']
    redirectUrl = resp.response['Location']
  end

  return '/' if( redirectUrl.nil? )

  response = URI.parse( redirectUrl )

  redirectUrl.gsub( format( '%s://%s', response.scheme, response.host ) ,'')
end


Open3.popen3('/usr/sbin/apachectl', '-S')  { |stdin, stdout, stderr, wait_thr|

  pid = wait_thr.pid # pid of the started process.

  while line = stdout.gets

    if( line =~ /port (.*) namevhost/ )

      parts = line.match( /^(.*)port (?<port>.+[0-9]) namevhost (?<vhost>.+[a-zA-Z0-9-]) \((?<path>.+[a-zA-Z0-9-]):\d\)$/ )

      vhost = parts['vhost'].to_s.strip if( parts )
      path  = parts['path'].to_s.strip if( parts )

      next if( vhost.nil? )
      next if( vhost =~ /^candy.*/ )

      o << {
        vhost => { url: '/' }
      }
    end
  end

  exit_status = wait_thr.value # Process::Status object returned.
}

r = o.reduce( {} , :merge )

r.each do |k,v|

  next if( k.nil? )

  url = format( 'http://%s%s', k, v[:url] )


  v[:url] = get_response_with_redirect( url )
end

r = { 'vhosts' => r }

puts JSON.pretty_generate(r)
