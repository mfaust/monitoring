
require 'ipaddress'
require 'open3'
require 'resolv'

module Utils

  class Network

    def self.resolv( host )

#       puts("self.resolv( #{host} )")

      line  = nil
      fqdn  = nil
      short = nil
      ip    = nil

      is_ip       = false
      is_hostname = true
      fqdn        = host

      # here comes an IP
      #
      if( IPAddress.valid?( host ) )
        is_ip       = true
        is_hostname = false
        ip          = host
      end

      # use dig for an reverse lookup ip => hostname
      #  dig -x $hostname +short
      if( is_ip == true )

        cmd = format( 'dig -x %s +short', host )
        Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|
          return_value = wait_thr.value
          std_out      = stdout.gets
          std_err      = stderr.gets

          # got the hostname for the IP-Address
          host = std_out if( return_value == 0 && !std_out.to_s.empty? )
        end
      end

#       puts(" #1 host  #{host} ")

      # use host to resolve hostname
      #  host -t A $hostname
      cmd   = format( 'host -t A %s', host )

      Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

        return_value = wait_thr.value
        std_out      = stdout.gets
        std_err      = stderr.gets

        line = std_out if( return_value == 0 && !std_out.to_s.empty? )
      end

#       puts(" #1 line  #{line} ")

      # the host command above was disfunctional
      # we try the ruby resolv class
      if( line == nil )

        begin
          ip   =  Resolv.getaddress( host )
          # BAD HACK
          # recursive call without a break :(
          #
          return self.resolv( ip )
        rescue => e
          puts ( e )
          return { ip: nil, short: nil, fqdn: nil }
        end
      end

      # finalize
      # i hope, we have all needed data
      #
      if( line != nil )

        parts = line.split( ' ' )

        # no A record found
        # panikmodus => ON
        return { ip: nil, short: nil, fqdn: nil } if(line.include?('has no A record') == true )

        # / # host -t A 172.31.41.133
        # Host 133.41.31.172.in-addr.arpa. not found: 3(NXDOMAIN)
        # panikmodus => ON
        return { ip: nil, short: nil, fqdn: nil } if(line.include?('not found') == true )

        # mls.development.cosmos.internal is an alias for ip-172-31-41-204.ec2.internal.
        #
        if( line.include?('is an alias for') == true )

          fqdn  = parts.last.strip

          # BAD HACK
          # recursive call without a break :(
          #
          r     = self.resolv( fqdn )

          ip    = r.dig(:ip)
          short = r.dig(:short)
          fqdn  = r.dig(:fqdn)
        else
          fqdn  = parts.first.strip
          ip    = parts.last.strip
          short = fqdn.split('.').first
        end

      end

      result = {
        ip: ip.nil? ? host : ip,
        short: short,
        fqdn: fqdn
      }
#       puts( "result: #{result}" )
      result
    end


    def self.ip( host )

      begin
        ip = Socket.gethostbyname( host ).first
      rescue => e
        ip = host
      end

      ip
    end


    def self.port_open? ( host, port, seconds = 1 )

      # => checks if a port is open or not on a remote host
      Timeout::timeout( seconds ) do

        begin
          TCPSocket.new( host, port ).close
          return true

        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e

          return false
        end

      end

      rescue Timeout::Error => e

        return false
    end


    def self.is_ip?( data )
      IPAddress.valid?( data ) # "192.128.0.12"  end
    end


    # check if Node exists (simple ping)
    # result @bool
    def self.is_running?( ip )

      return true if( system( format( 'ping -c1 -w1 %s > /dev/null', ip.to_s ) ) == true )

      return false
    end

  end
end
