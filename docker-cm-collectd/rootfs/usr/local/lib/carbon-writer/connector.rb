
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

        @connectors = options[:backends].map { |o| Connector.new(*o) }
      end

      def publish( messages )

        Array(messages).each { |msg| @connectors.map {|c| c.puts msg} }
      end
    end

    def initialize( host, port )
      @host, @port = host, port
    end

    def puts( message )

      begin

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

        @socket = ::TCPSocket.new @host, @port
      end

      @socket

    end

  end

end


