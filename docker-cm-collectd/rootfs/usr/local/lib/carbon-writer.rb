#!/usr/bin/ruby
#
#
# reads and parse the f*ing output of prometheus' node_exporter
# then put the result as json
#
#  (c) 2016 Coremedia (Bodo Schulz)
#

require_relative 'carbon-writer/version'
require_relative 'carbon-writer/logging'
require_relative 'carbon-writer/utils'
require_relative 'carbon-writer/buffer'
require_relative 'carbon-writer/cache'
require_relative 'carbon-writer/client'
require_relative 'carbon-writer/connector'

require_relative 'carbon-data'

# -------------------------------------------------------------------------------------------------

module CarbonWriter

  def self.version

    return CarbonWriter::VERSION

  end

  def self.new( options )

    Client.new( options )

  end

end



