
require_relative 'logging'
require_relative '../carbon-data'

module CarbonWriter

  class Client

    include Logging

    def initialize( params = {} )

#       logger.debug( params )

      @graphiteHost = params.dig( :graphite, :host )
      @graphitePort = params.dig( :graphite, :port )
      @slice        = params.dig( :slice )
      @buffer       = CarbonWriter::Buffer.new( { :cache => 4 * 60 * 60 } )
      @memcacheHost = params.dig( :memcache, :host )
      @memcachePort = params.dig( :memcache, :port )

      @carbonData   = CarbonData::Consumer.new( { :memcache => { :host => @memcacheHost, :port => @memcachePort } } )

    end


    def socket()

#       logger.debug( 'socket()' )

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


    def run()

      start = Time.now
#       logger.debug( 'start for getting data' )

      nodes = @carbonData.nodes()

      logger.debug( "#{nodes}" )

      nodes.each do |n|

        data = @carbonData.run( n )

        if( data.is_a?( Array ) )
          data.flatten!
        end
#         logger.debug( 'done' )
        finish = Time.now

        logger.info( sprintf( 'getting %s measurepoints in %s seconds', data.count, finish - start ) )

        data.each do |m|
          self.metric( m )
        end

      end

#      logger.debug( JSON.pretty_generate( data ) )
    end


    def metric( metric = {} )

#       logger.debug( sprintf( 'metric( %s )', metric ) )
      key   = metric.dig(:key)
      value = metric.dig(:value)
      time  = metric.dig(:time) || Time.now

      # TODO
      # value must be an float!

      if( key == nil || value == nil )
#         logger.error( 'ERROR' )
        if( key == nil )
          logger.error( 'missing \'key\' entry' )
          logger.debug( sprintf( 'metric( %s )', metric ) )
        end
        if( value == nil )
          logger.error( 'missing \'value\' entry' )
          logger.debug( sprintf( 'metric( %s )', metric ) )
        end

        return
      end

      metric = {
        :key   => key,
        :value => value,
        :time  => normalizeTime( time, @slice )
      }

      @buffer.push( metric )

      if( @buffer.new_records?() )

#         logger.debug( @buffer.pull( :string ) )

      end

      begin

#        logger.debug( "#{key} #{value} #{time.to_i}" )

        self.socket.write( "carbon-writer.#{key} #{value.to_f} #{time.to_i}\n" )

      rescue Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED

        @socket = nil
        nil

      end
    end


    def closeSocket()

      if( @socket )
        @socket.close
      end

      @socket = nil
    end


    private

    def normalizeTime( time, slice )

#       logger.debug( "normalizeTime( #{time}, #{slice} )" )

      if( slice.nil?() )
        slice = 1
      end

      result = ((time || Time.now).to_i / slice * slice).to_i

      return result
    end

  end

end
