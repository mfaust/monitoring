#!/usr/bin/ruby

require 'beaneater'
require 'json'

bs = Beaneater.new( 'localhost' )

puts bs.tubes['mq-information'].stats
puts ''


def foo( id, body, state, stats )

  puts id
  puts body

  sleep 2
end

tube = bs.tubes.find('mq-information')

while( job = tube.peek(:buried) )

  foo( job.id, job.body, job.stats.state, bs.jobs[ job.id ].stats )

  job.delete
end

#puts bs.tubes['mq-information'].peek(:buried)

loop do

  tube = bs.tubes.watch!('mq-information')

  job = bs.tubes.reserve

#   # => <Beaneater::Job id=5 body="foo">
#   puts job.id
#   puts job.body
#   # prints 'job-data-here'
#   puts job.stats.state
#
#   puts bs.jobs[ job.id ].stats
#
#   job.touch

  begin
    # processing job
    foo( job.id, job.body, job.stats.state, bs.jobs[ job.id ].stats )

    job.delete
  rescue Exception => e
    job.bury
  end

  puts '-----------------------------'

  puts bs.tubes['mq-information'].stats
  puts '-----------------------------'

end



return

p bs.stats.keys

tube = bs.tubes.find('mq-information')
puts tube


bs.tubes.watch!('mq-information')

loop do

  p bs.stats.keys
  p [bs.stats[:current_tubes], bs.stats[:total_jobs]]

  t = bs.tubes

  t.each do |tube|

    puts tube

    puts tube.stats

  end

  job = bs.tubes.reserve

  jid = job.id

  puts jid

  p bs.jobs.peek(jid)



end
