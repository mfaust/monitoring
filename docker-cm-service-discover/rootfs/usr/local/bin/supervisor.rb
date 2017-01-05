#!/usr/bin/ruby

require 'ruby-supervisor'


client = RubySupervisor::Client.new(
  '127.0.0.1',
  9001,
  :user     => 'supervisor',
  :password => 'supervisor'
)

puts "You are running supervisor version #{client.version}"
puts ""

# puts client.processes

['collectd','data-collector','monitoring-rest'].each do |p|

  process = client.process(p)

  n = process.infos['name']
  s = process.state

  puts sprintf( '%-20s  %s', n, s )

end


