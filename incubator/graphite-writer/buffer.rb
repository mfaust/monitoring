# -----------------------------------------------------
# Buffer Object
# Handle Socket & Client data streams
# -----------------------------------------------------
# Usage:
#     buff = GraphiteAPI::Buffer.new(GraphiteAPI::Utils.default_options)
#     buff << {:metric => {"load_avg" => 10},:time => Time.now}
#     buff << {:metric => {"load_avg" => 30},:time => Time.now}
#     buff.stream "mem.usage 1"
#     buff.stream "90 1326842563\n"
#     buff.stream "shuki.tuki 999 1326842563\n"
#     buff.pull.each {|o| p o}
#
# Produce:
#    ["load_avg", 40.0, 1326881160]
#    ["mem.usage", 190.0, 1326842520]
#    ["shuki.tuki", 999.0, 1326842520]
# -----------------------------------------------------

require 'thread'
require 'set'

require_relative 'logging'

module CarbonWriter

  class Buffer

    include Utils
    include Logging

#     CHARS_TO_BE_IGNORED = ["\r"]
#     END_OF_STREAM = "\n"
#     VALID_MESSAGE = /^[\w|\.|-]+ \d+(?:\.|\d)* \d+$/

    def initialize( options )

      logger.debug( options )

      @options  = options
      @queue    = Queue.new
#       @streamer = Hash.new { |h,k| h[k] = "" }

      if( options[:cache] )
        @cache    = Cache::Memory.new( options )
      end

    end

    private_reader :queue, :options, :streamer, :cache

    # this method isn't thread safe
    # use #push for multiple threads support
#     def stream( message, client_id = nil )
#
#       message.gsub(/\t/,' ').each_char do |char|
#
#         next if invalid_char? char
#         streamer[client_id] += char
#
#         if closed_stream? streamer[client_id]
#           if valid_stream_message? streamer[client_id]
#             push stream_message_to_obj streamer[client_id]
#           end
#           streamer.delete client_id
#         end
#       end
#
#     end

    # Add records to buffer
    # push({:metric => {'a' => 10},:time => Time.now})
    def push( obj )

      logger.debug( "push( #{obj} )" )

      queue.push( obj )

      nil

    end

    alias_method :<<, :push

    def pull( format = nil )

      logger.debug( sprintf( 'pull( %s )', format ) )

      data = nested_zero_hash()

      logger.debug( data )

      counter = 0

      while self.new_records?()

        logger.debug('. ')

        if ( counter += 1 ) > 1_000_000 # TODO: fix this
          break
        end

        hash = queue.pop

        time = normalize_time( hash.dig( :metric, :time ), options[:slice] )

        values = hash.values
        values.flatten!
#         logger.debug( "values: #{values}" )

        key = values.first.dig(:key)

        values.first.delete_if { |k,v| k == :key }
        values.first.each { |k,v| data[time][k] += v.to_f }

        data[:key] = key

      end

      logger.debug( "data #{data}" )


      data.map do |time, hash|

        logger.debug( time )
        logger.debug( hash )

        hash.map do |key, value|

          if cache
            value   = cache.incr( time, key, value )
          end

          results = ["#{prefix}#{key}",("%f"%value).to_f, time]
          format == :string ? results.join(" ") : results
        end

      end

      data.flatten(1)

#       logger.debug( data )

      return data

    end

    def new_records?
      !queue.empty?
    end

    def inspect
      "#<GraphiteAPI::Buffer:%s @quque#size=%s @streamer=%s>" %
        [ object_id, queue.size, streamer]
    end

    private

    def stream_message_to_obj( message )
      parts = message.split
      {:metric => { parts[0] => parts[1] },:time => Time.at(parts[2].to_i) }
    end

    def invalid_char? char
      CHARS_TO_BE_IGNORED.include? char
    end

    def closed_stream? string
      string[-1,1] == END_OF_STREAM
    end

    def valid_stream_message? message
      message =~ VALID_MESSAGE
    end

    def prefix
      @prefix ||= if options[:prefix] and !options[:prefix].empty?
        Array(options[:prefix]).join('.') << '.'
      else
        ""
      end
    end

  end
end
