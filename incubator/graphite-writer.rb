#!/usr/bin/ruby
#
#
# reads and parse the f*ing output of prometheus' node_exporter
# then put the result as json
#
#  (c) 2016 Coremedia (Bodo Schulz)
#

# require 'json'
# require 'rest-client'
require 'zscheduler'

require_relative 'graphite-writer/version'
require_relative 'graphite-writer/logging'
require_relative 'graphite-writer/utils'
require_relative 'graphite-writer/buffer'
require_relative 'graphite-writer/cache'
require_relative 'graphite-writer/client'
require_relative 'graphite-writer/connector'
require_relative 'graphite-writer/middleware'


# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------

module CarbonWriter

  def self.version

    return CarbonWriter::VERSION

  end

  def self.new options

    Client.new( options )

  end

end

require 'rufus-scheduler'


require 'rufus-scheduler'

s = Rufus::Scheduler.new

p [ :scheduled_at, Time.now ]

s.every '5s', :first_in => 0.4 do
  p [ :every,  Time.now ]
end

s.join


exit 0


options = {
  :graphite => { :host => 'web6.xanhaem.de', :port => 2003 },
  :interval => 60,
  :cache    => ( 4 * 60 * 60 )
}

client = CarbonWriter.new( options )

scheduler = Rufus::Scheduler.new

scheduler.every '15s', :first_in => 0.4 do
  client.metric( { :key => "webServer.web01.loadAvg" , :value => 10.7 } )
  client.metric( { :key => "webServer.web02.loadAvg" , :value => 1.0 } )
  client.metric( { :key => "webServer.web03.loadAvg" , :value => 0.3 } )
end

scheduler.join


