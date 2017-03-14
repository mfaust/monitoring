

# module CarbonWriter
#
#   module Cache
#     autoload :Memory, File.expand_path("../cache/memory", __FILE__)
#   end
#
# end

require_relative 'logging'

module CarbonWriter

  module Cache

    class Memory

      include Utils
      include Logging

      def initialize( options )

        scheduler = Rufus::Scheduler.new

        scheduler.every( 120 ) do
          clean( options[:cache] )
        end

      end

      def get( time, key )

        cache[time.to_i][key]
      end

      def set( time, key, value )

        cache[time.to_i][key] = value.to_f
      end

      def incr( time, key, value )

        self.set( time, key, value.to_f + self.get( time, key ) )
      end

      private

      def cache

        @cache ||= nested_zero_hash()

      end

      def clean( max_age )

        cache.delete_if { |t,k| Time.now.to_i - t > max_age }

      end

    end
  end
end
