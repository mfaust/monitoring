#!/usr/bin/ruby

require 'time'
require 'date'
require 'time_difference'

from = 1474156800000
hard = 1482105600000
soft = 1482105600000


t      = Date.parse( Time.now().to_s )
today  = Time.new( t.year, t.month, t.day )

license = Time.at( hard / 1000 ).strftime("%d.%m.%Y") ## -%m-%d %H:%M:%S")


## diff    = Time.now().to_i - Time.at( from / 1000 ).to_i

diff    = TimeDifference.between( today, license ).in_each_component


    def timeParser( today, finalDate )

#      final      = Date.parse( finalDate )
#      finalTime  = Time.new( final.year, final.month, final.day )
      difference = TimeDifference.between( today, finalDate ).in_each_component

      return {
        :years  => difference[:years].round,
        :months => difference[:months].round,
        :weeks  => difference[:weeks].round,
        :days   => difference[:days].round
      }
    end


puts today
puts license
puts diff

puts timeParser( today, license )
