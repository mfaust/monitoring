#!/usr/bin/ruby
#
#  (c) 2017 CoreMedia (Bodo Schulz)
#
# 1.2.0

require_relative 'carbon-writer/version'
require_relative 'carbon-writer/logging'
require_relative 'carbon-writer/client'

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

# EOF
