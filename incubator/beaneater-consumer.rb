#!/usr/bin/ruby

require 'beaneater'
require 'json'
require 'rufus-scheduler'

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

interval = 10

bs = Beaneater.new( 'localhost' )

puts ''
puts bs.tubes['mq-test'].stats
puts  ''


def foo( id, body, state, stats )

  puts id
  puts body

  sleep 2

  return false
end

scheduler = Rufus::Scheduler.new

tube = bs.tubes.find('mq-test')

scheduler.every( 5 ) do

  puts 'seek buried jobs'
#  puts bs.tubes['mq-test'].stats
  tube = bs.tubes.find('mq-test')

  buried = tube.peek(:buried)

  if( buried )

    puts "found job #{buried.id}"

    tube.kick(1)
  end

#  @beanstalk.tubes['some-tube'].kick(3)

#   tube = bs.tubes.find('mq-test')
#   tube = bs.tubes.watch!('mq-test')
#
#   puts '-----------------------------'
#   puts tube.inspect
#   puts '-----------------------------'
#
#   job = tube.peek(:buried)
#
#   puts job.inspect
#
#   # TODO
#   # more robustnes
#   if( job = tube.peek(:buried) )
#
#     puts 'found job: ' + job.id
#
#     # foo( job.id, job.body, job.stats.state, bs.jobs[ job.id ].stats )
#     # job.delete
#
#     job.kick
#
#   end
end

#puts bs.tubes['mq-information'].peek(:buried)

scheduler.every( interval, :first_in => 1 ) do

  puts 'run into a scheduler'

  tube = bs.tubes.watch!('mq-test')

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
    if( foo( job.id, job.body, job.stats.state, bs.jobs[ job.id ].stats ) == true )

      job.delete
    else

      puts 'processing failed.'
      puts 'bury job: ' + job.id

#      job.reserve
      job.bury

      puts job.stats.state # => 'buried'

    end
  rescue Exception => e
    job.bury
  end

  puts '-----------------------------'
  puts bs.tubes['mq-test'].stats
  puts '-----------------------------'

end

scheduler.every( '5s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end

end


scheduler.join


# -----------------------------------------------------------------------------


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
