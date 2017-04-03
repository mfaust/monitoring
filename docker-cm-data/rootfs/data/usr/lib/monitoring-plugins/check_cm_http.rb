#!/usr/bin/ruby

require_relative '/usr/local/lib/icingachecks.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check_HTTP < Icinga2Check

  def initialize( settings = {} )

    super

    host         = settings[:host]        ? settings[:host]        : nil
    application  = settings[:application] ? settings[:application] : nil

    host         = self.shortHostname( host )

    self.check( host, application )

  end


  def check( host, application )


  end

end

# ---------------------------------------------------------------------------------------

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-h', '--host NAME'       , 'Host with running Application')                   { |v| options[:host]  = v }
  opts.on('-a', '--application APP' , 'Name of the running Application')                 { |v| options[:application]  = v }

end.parse!

m = Icinga2Check_HTTP.new( options )
