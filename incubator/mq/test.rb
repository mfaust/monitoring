#!/usr/bin/env ruby

require 'beaneater'
require 'json'
require 'rufus-scheduler'

require_relative 'message-queue'

# -----------------------------------------------------------------------------

# NEVER FORK THE PROCESS!
# the used supervisord will control all
stop = false

Signal.trap('INT')  { stop = true }
Signal.trap('HUP')  { stop = true }
Signal.trap('TERM') { stop = true }
Signal.trap('QUIT') { stop = true }

# -----------------------------------------------------------------------------

scheduler = Rufus::Scheduler.new

scheduler.every( 5 ) do

  if( stop == true )

    puts 'shutdown scheduler ...'

    scheduler.shutdown(:kill)
  end

end

# -----------------------------------------------------------------------------
# TESTS

queue = 'mq-test'

settings = {
  :beanstalkHost  => 'localhost',
  :beanstalkQueue => queue
}

# -----------------------------------------------------------------------------

p = MessageQueue::Producer.new( settings )
c = MessageQueue::Consumer.new( settings )

def proceed( job )

  puts JSON.pretty_generate( job )

  jobId = job.dig( :id )

#  return jobId % 2

  return true

end

# PRODUCER
scheduler.every( 240, :first_in => 1 ) do

  puts 'produce jobs'

  5.times do |i|

    q = sprintf( "%s-%s", queue, i )

    job = {
      cmd:   'add',
      payload: sprintf( "foo-bar-%s.com", i )
    }.to_json

    p.addJob( q, job )
  end

end

# CONSUMER
scheduler.every( 5, :first_in => 5 ) do

  puts 'consume jobs'

  5.times do |i|

    q = sprintf( "%s-%s", queue, i )

    j = c.getJobFromTube( q )

#     puts j

    if( j.count != 0 )

#       puts JSON.pretty_generate( c.tubeStatistics( q ) )

      jobId = j.dig( :id )

      if( proceed( j ) == true )

        c.deleteJob( q, jobId )
      else

        c.buryJob( q, jobId )
      end
    end
  end


  j = c.getJobFromTube( queue )

  if( j.count != 0 )

#     puts JSON.pretty_generate( c.tubeStatistics( queue ) )

    jobId = j.dig( :id )

    if( proceed( j ) == true )

      c.deleteJob( queue, jobId )
    else

      c.buryJob( queue, jobId )
    end
  end

end

# -----------------------------------------------------------------------------

scheduler.join
