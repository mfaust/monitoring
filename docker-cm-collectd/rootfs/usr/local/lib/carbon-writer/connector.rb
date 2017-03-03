
# -----------------------------------------------------
# TCP Socket connection
# -----------------------------------------------------
# Usage:
#    connector = GraphiteAPI::Connector.new("localhost",2003)
#    connector.puts("my.metric 1092 1232123231")
#
# Socket:
# => my.metric 1092 1232123231\n
# -----------------------------------------------------

require 'socket'

require_relative 'logging'

module CarbonWriter

  class Connector

    include Logging

    class Group

      include Logging

      def initialize( options )

        logger.debug( options )
        @connectors = options[:backends].map { |o| Connector.new(*o) }
      end

      def publish( messages )

        logger.debug( [ :connector_group, :publish, messages.size, @connectors ] )

        Array(messages).each { |msg| @connectors.map {|c| c.puts msg} }
      end
    end

    def initialize( host, port )
      @host, @port = host, port
    end

    def puts( message )

      begin

        logger.debug( [ :connector, :puts, [ @host, @port ].join( ':' ), message ] )

        socket.puts message + "\n"
      rescue Errno::EPIPE, Errno::EINVAL, Errno::ETIMEDOUT

        @socket = nil
      retry
      end

    end

    def inspect()
      "#{self.class} #{@host}:#{@port}"
    end

    protected

    def socket()

      if @socket.nil? || @socket.closed?

        logger.debug( [ :connector,[ @host, @port ] ] )
        @socket = ::TCPSocket.new @host, @port
      end

      @socket

    end

  end

end


