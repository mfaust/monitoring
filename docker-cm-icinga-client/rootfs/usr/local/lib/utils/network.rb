
require 'ipaddress'
require 'open3'
require 'resolv'

module Utils

  class Network

    def self.resolv( host )

      line  = nil
      long  = nil
      short = nil
      ip    = nil

      # here comes an IP
      #
      if( IPAddress.valid?( host ) )

        isIP       = true
        isHostname = false

        ip         = host
      else

        isIP       = false
        isHostname = true

        long       = host
      end


      if( isIP == true )

        # use dig to make an reverse lookup
        #
        cmd = sprintf( 'dig -x %s +short', host )

        Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

          returnValue = wait_thr.value
          stdOut      = stdout.gets
          stdErr      = stderr.gets

          if( returnValue == 0 && !stdOut.to_s.empty? )

            # got the hostname for the IP-Address
            #
            host = stdOut
          else

          end
        end

      end

      line  = nil

      # we have an hostname
      #
      cmd   = sprintf( 'host -t A %s', host )

      Open3.popen3( cmd ) do |stdin, stdout, stderr, wait_thr|

        returnValue = wait_thr.value
        stdOut      = stdout.gets
        stdErr      = stderr.gets

        if( returnValue == 0 && !stdOut.to_s.empty? )

          line = stdOut
        else

        end
      end


      # the host command above was disfunctional
      # we try the ruby resolv class
      if( line == nil )

        begin

          ip   =  Resolv.getaddress( host )

          return self.resolv( ip )

        rescue => e

          puts ( e )

          return {
            :ip    => nil,
            :short => nil,
            :long  => nil
          }

        end

      end

      # finalize
      # i hope, we have all needed data
      #
      if( line != nil )

        parts = line.split( ' ' )

        long  = parts.first.strip
        ip    = parts.last.strip
        short = long.split('.').first

      end

      result = {
        :ip    => ip != nil ? ip : host,
        :short => short,
        :long  => long
      }

      puts( result )

      return result

    end

    def self.ip( host )

      begin
        ip = Socket.gethostbyname( host ).first
      rescue => e
        ip = host
      end

      return ip
    end


    def self.portOpen? ( host, port, seconds = 1 )

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



    def self.isIp?( data )

      return IPAddress.valid?( data ) # "192.128.0.12"  end
    end

    # check if Node exists (simple ping)
    # result @bool
    def self.isRunning? ( ip )

      puts "pinging IP #{ip} ... "

      # first, ping check
      if( system( sprintf( 'ping -c1 -w1 %s > /dev/null', ip.to_s ) ) == true )
        return true
      else
        return false
      end

    end

  end
end
