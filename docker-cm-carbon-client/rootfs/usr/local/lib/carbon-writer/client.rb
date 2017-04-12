
require_relative 'logging'
require_relative '../carbon-data'

module CarbonWriter

  class Client

    include Logging

    def initialize( settings = {} )

      redisHost           = settings.dig(:redis, :host)
      redisPort           = settings.dig(:redis, :port)             || 6379

      @graphiteHost = settings.dig( :graphite, :host )
      @graphitePort = settings.dig( :graphite, :port )
#       @slice        = settings.dig( :slice )
#       @memcacheHost = params.dig( :memcache, :host )
#       @memcachePort = params.dig( :memcache, :port )

      version             = '1.3.0'
      date                = '2017-04-12'

      logger.info( '-----------------------------------------------------------------' )
      logger.info( ' CoreMedia - Carbon client' )
      logger.info( "  Version #{version} (#{date})" )
      logger.info( '  Copyright 2016-2017 Coremedia' )
      logger.info( '  used Services:' )
      logger.info( "    - carbon       : #{@graphiteHost}:#{@graphitePort}" )
#       logger.info( "    - message queue: #{mqHost}:#{mqPort}/#{@mqQueue}" )
#       logger.info( '-----------------------------------------------------------------' )
      logger.info( '' )

      @carbonData   = CarbonData::Consumer.new( { :redis => { :host => redisHost, :port => redisPort } } )
#       @buffer       = CarbonWriter::Buffer.new( { :cache => 4 * 60 * 60 } )

    end


    def socket()

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
      nodes = @carbonData.nodes()

      nodes.each do |n|

        data = @carbonData.run( n )

        if( data.is_a?( Array ) )
          data.flatten!
        end

        finish = Time.now

        logger.info( sprintf( 'getting %s measurepoints in %s seconds', data.count, finish - start ) )

        data.each do |m|
          self.metric( m )
        end

      end

    end


    def metric( metric = {} )

      key   = metric.dig(:key)
      value = metric.dig(:value)
      time  = metric.dig(:time) || Time.now

      # TODO
      # value must be an float!

      if( key == nil || value == nil )

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

#       metric = {
#         :key   => key,
#         :value => value,
#         :time  => normalizeTime( time, @slice )
#       }
#
#       @buffer.push( metric )
#
#       if( @buffer.new_records?() )
#
# #         logger.debug( @buffer.pull( :string ) )
#
#       end

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

      if( slice.nil?() )
        slice = 1
      end

      result = ((time || Time.now).to_i / slice * slice).to_i

      return result
    end

  end

end
