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


options = {
  :graphite => { :host => 'web6.xanhaem.de', :port => 2003 },
  :interval => 60,
  :cache    => ( 4 * 60 * 60 )
}

client = CarbonWriter.new( options )

# client = CarbonWriter.new(
#   graphite: "graphite.example.com:2003", # required argument
#   prefix: ["example","prefix"],          # add example.prefix to each key
#   slice: 60,                             # results are aggregated in 60 seconds slices
#   interval: 60,                          # send to graphite every 60 seconds
#                                          # default is 0 ( direct send )
#   cache: 4 * 60 * 60,                    # set the max age in seconds for records reanimation
# )

client.report( { :key => "webServer.web01.loadAvg" , :value => 10 } )

# client.metrics(
#   {
#   "webServer.web01.loadAvg"  => 10.7,
#   "webServer.web01.memUsage" => 40
#   }, Time.at(1326067060)
# )


