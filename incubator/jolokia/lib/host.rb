#!/usr/bin/ruby

require 'sqlite3'
require 'socket'
require 'timeout'
require 'logger'
require 'json'

# -------------------------------------------------------------------------------------------------------------------

class Discover

  def initialize

#    file = File.open( '/tmp/monitor.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @tmp_dir     = '/var/cache/monitoring'

    @information = Hash.new()

#    Dir.mkdir( @tmp_dir ) unless File.exist?( @tmp_dir )
#
#    self.databaseConnect
  end

  def databaseConnect

    begin
      @db = SQLite3::Database.new( @tmp_dir + '/database.db' )
      @log.debug( @db.get_first_value 'SELECT SQLITE_VERSION()' )

    rescue SQLite3::Exception => e
      puts e.errno
      puts e.error

#    ensure
#      if @db
#        @db.close
#      end
    end

  end

  # check if Node exists (simple ping)
  # result @bool
  def isRunning? ( ip )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

      @log.info( sprintf( '  node %-13s are available', ip.to_s ) )
      return true
    else
      @log.info( sprintf( '  node %-13s are NOT available', ip.to_s ) )
      return false
    end

  end

  def port_open? ( ip, port, seconds = 1 )
    # => checks if a port is open or not on a remote host
    Timeout::timeout( seconds ) do
      begin
        TCPSocket.new( ip, port ).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        false
      end
    end
    rescue Timeout::Error
      false

  end

  def createHostOnDatabase( host )

    running = self.isRunning? ( host.to_str )

    if @db

      begin
        @db.execute "CREATE TABLE IF NOT EXISTS hosts   ( name string not null PRIMARY KEY, alive int )"
#        @db.execute "CREATE TABLE IF NOT EXISTS ports   ( id integer primary key autoincrement, host string not null, port int, status int, CONSTRAINT constraint_name unique( host, port ) )" # on conflict ignore )" # UNIQUE (col_name1, col_name2) ON CONFLICT REPLACE)
        @db.execute "CREATE TABLE IF NOT EXISTS ports   ( host string not null, port int, status int, CONSTRAINT constraint_name unique( host, port ) )" # on conflict ignore )" # UNIQUE (col_name1, col_name2) ON CONFLICT REPLACE)
        @db.execute "CREATE TABLE IF NOT EXISTS service ( id integer primary key autoincrement, host string not null, port int, service string, CONSTRAINT constraint_name unique( host, port, service ) )" # on conflict ignore )" # UNIQUE (col_name1, col_name2) ON CONFLICT REPLACE)
        @db.execute "CREATE TABLE IF NOT EXISTS checks  ( id INTEGER PRIMARY KEY, host string not null, id_ports int, checks text )"

        stm = @db.prepare "insert or replace into hosts ( name, alive ) values ( ?, ? )"

#        stm.bind_param 1, 'null'
        stm.bind_param 1, host
#        stm.bind_param 3, 'null'
        stm.bind_param 2, running ? 1 : 0

        rs = stm.execute

      rescue SQLite3::Exception => e
        puts "Exception occurred"
        puts e
#        puts e.errno
#        puts e.error

#      ensure
#        if @db
#          @db.close
#        end
      end




    end



  end


  def createPortsOnDatabase( host, port, status )

    service = self.discoverApplication( host, port )

    if @db

      begin

        stm = @db.prepare "insert or replace into ports ( host, port, status ) values ( ?, ?, ? )"

        stm.bind_param 1, host
        stm.bind_param 2, port
        stm.bind_param 3, status ? 1 : 0

        rs = stm.execute

      rescue SQLite3::Exception => e
        puts "Exception occurred"
        puts e

      end
    end

  end


  def discoverApplication( host, port )

    @log.debug( sprintf( 'check port %s for service ', port.to_s  ) )

    service = ''

    if( port == 3306 or port == 5432 or port == 28017 )

      case port
      when 3306
        service = 'mysql'
      when 5432
        service = 'postgres'
      when 28017
        service = 'mongodb'
      end
    else

      # hash for the NEW Port-Schema
      hash = {
        :type => "read",
        :mbean => "java.lang:type=Runtime",
        :attribute => [
          "ClassPath"
        ],
        :target => {
          :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
        }
      }

      require 'net/http'
      require 'json'
      require 'uri'

      uri          = URI.parse( 'http://localhost:8080' )
      http         = Net::HTTP.new( uri.host, uri.port )

      request      = Net::HTTP::Post.new( '/jolokia/' )
      request.add_field('Content-Type', 'application/json')
      request.body = JSON.generate( hash )

      begin

        response     = http.request( request )

      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error

        case error
        when Errno::ECONNREFUSED
          @log.error( 'connection refused' )
        when Errno::ECONNRESET
          @log.error( 'connection reset' )
        end
      else

        body         = JSON.parse( response.body )

#         @log.debug( body )

        if( body['status'] == 200 )

          classPath  = body['value']['ClassPath'] ? body['value']['ClassPath'] : nil

          if( classPath.include?( 'cm7-tomcat-installation' ) )
            @log.debug( 'old style' )

            hash = {
              :type => "read",
              :mbean => "Catalina:type=Engine",
              :attribute => [
                'baseDir',
                'jvmRoute'
              ],
              :target => {
                :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
              }
            }

            request.body = JSON.generate( hash )
            response     = http.request( request )
            body         = JSON.parse( response.body )

            if( body['status'] == 200 )

              baseDir   = body['value']['baseDir'] ? body['value']['baseDir'] : nil
#              jvmRoute  = body['value']['jvmRoute'] ? body['value']['jvmRoute'] : nil

#              @log.debug( sprintf( '  =>  %s', baseDir ) )
#              @log.debug( sprintf( '  =>  %s', jvmRoute ) )

              regex = /
                ^                           # Starting at the front of the string
                (.*)                        #
                \/cm7-                      #
                (?<service>.+[a-zA-Z0-9-])  #
                (.*)-tomcat                 #
                $
              /x

              parts           = baseDir.match( regex )
            end

          else

            regex = /
              ^                           # Starting at the front of the string
              (.*)                        #
              \/coremedia\/               #
              (?<service>.+[a-zA-Z0-9-])  #
              \/current                   #
              (.*)                        #
              $
            /x

            parts           = classPath.match( regex )
          end


#           if( classPath != nil )

#            regex = /
#              ^                           # Starting at the front of the string
#              (.*)                        #
#              \/coremedia\/               #
#              (?<service>.+[a-zA-Z0-9-])  #
#              \/current                   #
#              (.*)                        #
#              $
#            /x
#
#            parts           = classPath.match( regex )

            if( parts )
              service         = "#{parts['service']}".strip.tr( '. ', '' )

              @log.debug( sprintf( '  => %s', service ) )
            else
              @log.error( 'unknown' )
            end
#           end

        else
          # uups
        end

      end

    end
    return service
  end


  def run( host = nil, ports = [] )

#    self.createHostOnDatabase( host )

    services = Hash.new()

    open = false

    ports.each do |p|

      if port_open?( host, p )
#         @log.info( "[OPEN]: Port #{p} is open on host #{host}" )
        open = true
      else
#         @log.debug( "[NOT OPEN]: Port #{p} is not open on host #{host}" )
        open = false
      end

      if( open == true )

        name = self.discoverApplication( host, p )

        services.merge!( { p => { 'name' => name, :running => true } } )

#        self.createPortsOnDatabase( host, p, open )
      else
        services.merge!( { p => { 'name' => 'unknown', 'running' => false } } )
      end

    end

    @information = { host => services }

    @log.info( JSON.pretty_generate( @information ) )
  end

end




class Discover2

  def initialize( host = nil, ports = [] )

    if isRunning? ( host )

#    createHostOnDatabase( host )

    open = false

    ports.each do |p|

      if port_open?( host, p )
        puts "[OPEN]: Port #{p} is open on host #{host}"
        open = true
      else
        puts "[NOT OPEN]: Port #{p} is not open on host #{host}"
        open = false
      end

#      insertIntoDB( host, p, open )
    end

    end

  end

  # check if Node exists (simple ping)
  # result @bool
  def isRunning? ( ip )

    # first, ping check
    if( system( 'ping -c1 -w1 ' + ip.to_s + ' > /dev/null' ) == true )

      puts ( sprintf( '  node %-13s are available', ip.to_s ) )
      return true
    else
      puts ( sprintf( '  node %-13s are NOT available', ip.to_s ) )
      return false
    end

  end

  def port_open? ( ip, port, seconds = 1 )
    # => checks if a port is open or not on a remote host
    Timeout::timeout( seconds ) do
      begin
        TCPSocket.new( ip, port ).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        false
      end
    end
    rescue Timeout::Error
      false

  end

end


# host  = 'master-75-tomcat'
# ports = [3306,5432,28017,38099,39099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099]


# ports = [40099,43099]

# d = Discover.new( host, ports )


# m = Discover.new()
# m.databaseConnect
# m.run( host, ports )


#class HandleTemplates
#
#  Dir.chdir( dir )
#  Dir.glob( '*.tpl' ).select { |f| File.directory? f }
#
#end
