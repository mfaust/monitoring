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

scheduler.every( '5s' ) do

  if( stop == true )

    p "shutdown scheduler ..."

    scheduler.shutdown(:kill)
  end

end

# -----------------------------------------------------------------------------
# TESTS

settings = {
  :beanstalkHost => 'localhost'
}

queue = 'mq-test'

# -----------------------------------------------------------------------------

p = MessageQueue::Producer.new( settings )
c = MessageQueue::Consumer.new( settings )

def proceed( job )

  puts JSON.pretty_generate( job )

  return false

end

# PRODUCER
# scheduler.every( 45, :first_in => 1 ) do
#
#   5.times do |i|
#
#     job = {
#       cmd:   'add',
#       payload: sprintf( "foo-bar-%s.com", i )
#     }.to_json
#
#     p.addJob( queue, job )
#   end
#
# end

# CONSUMER
scheduler.every( 10, :first_in => 1 ) do

  puts JSON.pretty_generate( c.tubeStatistics( queue ) )

  j = c.getJobFromTube( queue )

  if( j.count != 0 )

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
