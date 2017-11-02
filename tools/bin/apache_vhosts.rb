#!/usr/bin/env ruby

require 'open3'
require 'json'

o = []

Open3.popen3('/usr/sbin/apache2ctl', '-S')  { |stdin, stdout, stderr, wait_thr|

  pid = wait_thr.pid # pid of the started process.

  while line = stdout.gets

    if( line =~ /port (.*) namevhost/ )

      parts = line.match( /^(.*)port (?<port>.+[0-9]) namevhost (?<vhost>.+[a-zA-Z0-9-]) \((?<path>.+[a-zA-Z0-9-]):\d\)$/ )

      vhost = parts['vhost'].to_s.strip if( parts )
      path  = parts['path'].to_s.strip if( parts )

      o << {
        vhost => { url: '/' }
      }
    end
  end

  exit_status = wait_thr.value # Process::Status object returned.
}

r = o.reduce( {} , :merge )

puts JSON.pretty_generate(r)
