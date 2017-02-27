
require_relative 'logging'

module CarbonWriter

  class Client

    include Logging

    def initialize( params = {} )

      logger.debug( params )

      @graphiteHost = params.dig( :graphite, :host )
      @graphitePort = params.dig( :graphite, :port )
      @slice        = params.dig( :slice )

      @buffer       = CarbonWriter::Buffer.new( { :cache => 4 * 60 * 60 } )

    end


    def socket()

      logger.debug( 'socket()' )

      if( ! @socket || @socket.closed? )

        begin

          @socket = TCPSocket.new( @graphiteHost, @graphitePort )

        rescue => e

          logger.error( e )

        retry
          sleep( 5 )
        end
      end

      return @socket

    end


    def metric( metric = {} )

      logger.debug( sprintf( 'metric( %s )', metric ) )
      key   = metric.dig(:key)
      value = metric.dig(:value)
      time  = metric.dig(:time) || Time.now

      # TODO
      # value must be an float!

      if( key == nil || value == nil )
        logger.error( 'ERROR' )
        return
      end

      value = value.to_f
      time  = time.to_i

      metric = {
        :key   => key,
        :value => value,
        :time  => normalizeTime( time, @slice )
      }

#       logger.debug( metric )

      @buffer.push( metric )

      if( @buffer.new_records?() )

        logger.debug( @buffer.pull( :string ) )

      end

#       begin
#
#         puts( "#{key} #{value.to_f} #{time.to_i}\n" )
#
# #        self.socket.write( "#{key} #{value.to_f} #{time.to_i}\n" )
#
#       rescue Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED
#
#         @socket = nil
#         nil
#
#       end
    end

    def closeSocket()

      if( @socket )
        @socket.close
      end

      @socket = nil
    end


    private

    def normalizeTime( time, slice )

      logger.debug( "normalizeTime( #{time}, #{slice} )" )

      if( slice.nil?() )
        slice = 1
      end

      result = ((time || Time.now).to_i / slice * slice).to_i

      return result
    end



  end


  class ClientOld

    include Utils
    include Logging

    private_reader :options, :buffer, :connectors

    def initialize( opt, params = {} )

      graphiteHost = params.dig( :graphite, :host )
      graphitePort = params.dig( :graphite, :port )

      @options    = self.build_options( self.validate( opt.clone ) )

      logger.debug( opt )
      logger.debug( @options )

      @buffer     = CarbonWriter::Buffer.new( options )
      @connectors = CarbonWriter::Connector::Group.new( options )

      if( options[:direct] == false )
        Zscheduler.every( options[:interval] ) { self.send_metrics }
      end
    end

#     def_delegator Zscheduler, :loop, :join
#     def_delegator Zscheduler, :stop

    def every( interval, &block )
      Zscheduler.every( interval ) { block.arity == 1 ? block.call(self) : block.call }
    end

    def metrics( metric, time = Time.now )

      if metric.empty?
        return
      end

      buffer.push( :metric => metric, :time => time )

      if options[:direct]
        self.send_metrics()
      end
    end

#     alias_method :add_metrics, :metrics

    # increment keys
    #
    # increment("key1","key2")
    # => metrics("key1" => 1, "key2" => 1)
    #
    # increment("key1","key2", {:by => 999})
    # => metrics("key1" => 999, "key2" => 999)
    #
    # increment("key1","key2", {:time => Time.at(123456)})
    # => metrics({"key1" => 1, "key2" => 1},Time.at(123456))
#     def increment(*keys)
#       opt = {}
#       opt.merge! keys.pop if keys.last.is_a? Hash
#       by = opt.fetch(:by,1)
#       time = opt.fetch(:time,Time.now)
#       metric = keys.inject({}) {|h,k| h.tap { h[k] = by}}
#       metrics(metric, time)
#     end
#
#     def join
#       sleep while buffer.new_records?
#     end
#
#     def method_missing m, *args, &block
#       Proxy.new( self ).send(m,*args,&block)
#     end
#
#     protected
#
#     class Proxy
#       def initialize client
#         @client, @keys = client, []
#       end
#
#       def method_missing m, *args, &block
#         if @keys.push(m).size > 10
#           super # too deep
#         elsif args.any?
#           @client.metrics Hash[
#             @keys.join('.'), args.first
#           ], *args[1..-1]
#         else
#           self
#         end
#       end
#     end
#
    def validate( options )

      options.tap do |opt|
        raise ArgumentError.new ":graphite must be specified" if opt[:graphite].nil?
      end

    end

    def build_options( opt )

      default_options.tap do |options_hash|

        options_hash[:backends].push( self.expand_host( opt.delete( :graphite ) ) )
        options_hash.merge!( opt )
        options_hash[:direct] = options_hash[:interval] == 0
        options_hash[:slice]  = 1 if options_hash[:direct]

      end
    end

    def expand_host( host )

      if host =~ /:\/\//
        uri = URI.parse host
        [ uri.host, uri.port || default_options[:port] ]
      else
        host, port = host.split(":")
        port = port.nil? ? default_options[:port] : port.to_i
        [ host, port]
      end
    end

    def send_metrics()

      logger.debug( 'send_metrics()' )

      if( buffer.new_records?() )

        connectors.publish( buffer.pull( :string ) )

      end

    end


  end
end
