

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

        logger.debug( options )

        Zscheduler.every(120) { clean( options[:cache] ) }

      end

      def get( time, key )

        logger.debug( sprintf( 'get( %s, %s )', time, key ) )

        cache[time.to_i][key]
      end

      def set( time, key, value )

        logger.debug( sprintf( 'set( %s, %s, %s )', time, key, value ) )
        cache[time.to_i][key] = value.to_f
      end

      def incr( time, key, value )

        logger.debug( 'incr()' )
        self.set( time, key, value.to_f + self.get( time, key ) )
      end

      private

      def cache

        @cache ||= nested_zero_hash()

#         logger.debug( @cache )
      end

      def clean( max_age )

        logger.debug( "before_clean  #{cache}" )

        cache.delete_if { |t,k| Time.now.to_i - t > max_age }

        logger.debug( "after_clean  #{cache}" )

      end

    end
  end
end
