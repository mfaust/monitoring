
require 'ipaddress'
# require 'open3'
require 'resolv'
require 'net/ping'

module Utils

  class DnsCheck
    attr_reader :host
    def initialize(host)
      @host = host
    end

    def a
      @a ||= Resolv::DNS.new.getresources(@host, Resolv::DNS::Resource::IN::A)
    end

    def a?
      a.any?
    end

    def mx
      @mx ||= Resolv::DNS.new.getresources(@host, Resolv::DNS::Resource::IN::MX)
    end

    def mx?
      mx.any?
    end

    def ns
      @ns ||= Resolv::DNS.new.getresources(@host, Resolv::DNS::Resource::IN::NS)
    end

    def ns?
      ns.any?
    end

    def cname
      @cname ||= Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN::CNAME)
    end

    def cname?
      cname.any?
    end
  end

  class Network

    def self.resolv( host )
#       $stdout.puts("self.resolv( #{host} )")
      result = { ip: nil, short: nil, fqdn: nil }

      begin
        ip      = Resolv.getaddresses( host ).sort.last
        fqdn    = Resolv.getnames( ip ).sort.last

        fqdn    = host if( DnsCheck.new( host ).cname? )
        fqdn    = host if( fqdn != host ) unless( IPAddress.valid?( host ) )

        short   = fqdn.split('.')
        short   = if( short.count > 2 )
          short.first
        else
          fqdn
        end

        result = { ip: ip, short: short, fqdn: fqdn }

      rescue => error
        result = { ip: nil, short: nil, fqdn: nil }
      end

#       $stdout.puts( "result: #{result}" )
      result
    end

    # is the port open?
    #
    def self.port_open? ( host, port, seconds = 1 )
      # => checks if a port is open or not on a remote host
      Timeout::timeout( seconds ) do
        begin
          TCPSocket.new( host, port ).close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => error
          return false
        end
      end
      rescue Timeout::Error => error
        return false
    end

    # check if this an ip
    def self.is_ip?( data )
      IPAddress.valid?( data ) # "192.128.0.12"  end
    end


    # check if Node exists (simple ping)
    # result @bool
    def self.is_running?( ip )
      check = Net::Ping::ICMP.new(ip,1,1) # (host=nil, port=nil, timeout=5)
      check.ping?
#      return true if( system( format( 'ping -c1 -w1 %s > /dev/null', ip.to_s ) ) == true )
#      false
    end

  end
end
