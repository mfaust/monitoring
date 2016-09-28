#!/usr/bin/ruby

# OBSOLETE

require 'sqlite3'
require 'socket'
require 'timeout'
require 'logger'
require 'json'

# -------------------------------------------------------------------------------------------------------------------

class Monitor

  def initialize

    file = File.open( '/tmp/monitor.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
#    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

#    @known_ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,48099,49099]
    @known_ports = [40099]
    @tmp_dir     = '/var/cache/monitoring'

    self.databaseConnect
  end

  def databaseConnect

    begin
      @db = SQLite3::Database.new( @tmp_dir + '/database.db' )
#      @log.debug( @db.get_first_value 'SELECT SQLITE_VERSION()' )

    rescue SQLite3::Exception => e
#      puts e.errno
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

  def createHostOnDatabase( host )

#    running = self.isRunning? ( host.to_str )

    if @db

      begin
        @db.execute "CREATE TABLE IF NOT EXISTS hosts   ( name string not null PRIMARY KEY, created string not null, updated string not null, alive int )"
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

    types = [
      'manager',
      'blueprint',
      'drive',
      'solr',
      'user-changes',
      'workflow',
      'webdav',
      'elastic-worker',
      'coremedia',
      'contentfeeder',
      'caefeeder',
      'studio',
      'editor-webstart',
      'demodata-generator'
     ]
#    types = ['coremedia','solr']

    if port == 3306 or port == 5432 or port == 28017
      return
    end

    types.each do |t|

      @log.debug( sprintf( 'check port %s for service %s', port.to_s, t.to_s  ) )

      hash1 = {
        :type => "read",
        :mbean => sprintf( "Catalina:j2eeType=WebModule,J2EEApplication=none,J2EEServer=none,name=//localhost/%s", t.to_s ),
        :attribute => [
          "docBase",
          "configFile",
          "baseName",
          "workDir",
          "path"
        ],
        :target => {
          :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
        }
      }

#       @log.debug( JSON.generate( hash1 ) )

      require 'net/http'
      require 'json'
      require 'uri'

      uri          = URI.parse( 'http://jolokia:8080' )
      http         = Net::HTTP.new( uri.host, uri.port )

      request      = Net::HTTP::Post.new( '/jolokia/' )
      request.add_field('Content-Type', 'application/json')
      request.body = JSON.generate( hash1 )

      response     = http.request( request )
      body         = JSON.parse( response.body )

#       @log.debug( ( body['status'] ) )

      if body['status'] == 200

#         @log.debug( JSON.pretty_generate( body ) )

        File.open( sprintf( '/tmp/cm_%s_%s.result', port, t ) , 'w') do |f|
          f.write(  JSON.pretty_generate( body ) )
        end
      else

        types.each do |type|

          hash2 = {
            :type => "read",
            :mbean => sprintf( "Catalina:type=Manager,context=/%s,host=localhost", type ),
            :attribute => [
              "jvmRoute"
            ],
            :target => {
              :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port )
            }
          }

#           @log.debug( JSON.generate( hash2 ) )
            request      = Net::HTTP::Post.new( '/jolokia/' )
            request.add_field('Content-Type', 'application/json')
            request.body = JSON.generate( hash2 )

          response     = http.request( request )
          body         = JSON.parse( response.body )

#           @log.debug( ( body['status'] ) )

          if body['status'] == 200

            File.open( sprintf( '/tmp/cm_%s_%s.result', port, t ) , 'w') do |f|
              f.write(  JSON.pretty_generate( body ) )
            end

          end

        end
#        @log.debug( JSON.pretty_generate( body ) )

      end

#      @log.debug( response.code )
#      body = JSON.parse( response.body )
#
#      @log.debug( ( body['status'] ) )


#   require 'jolokia'
#
#   jolokia = Jolokia.new(url: 'http://jolokia:8080/jolokia')
#
#   response = jolokia.request(
#     :post,
#     type: 'read',
#     mbean: sprintf( "Catalina:j2eeType=WebModule,J2EEApplication=none,J2EEServer=none,name=//localhost/%s", t.to_s ),
#     attribute: 'HeapMemoryUsage',
#     target: { :url => sprintf( "service:jmx:rmi:///jndi/rmi://%s:%s/jmxrmi", host, port ) }
#   )
#
# #      get_attribute(mbean, attribute, path = nil, target = nil)


#      @log.debug( response )

    end
  end


  def run( host = nil, ports = [] )

    if isRunning? ( host )

      self.createHostOnDatabase( host )

      open = false

      ports.each do |p|

        if port_open?( host, p )
          puts "[OPEN]: Port #{p} is open on host #{host}"
          open = true
        else
          puts "[NOT OPEN]: Port #{p} is not open on host #{host}"
          open = false
        end

        if( open == true )

          self.createPortsOnDatabase( host, p, open )
        end

      end

    end

  end



end




class Discover

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


host  = 'master-75-tomcat'
ports = [3306,5432,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099]
# ports = [40099,43099]

# d = Discover.new( host, ports )


m = Monitor.new()
# m.databaseConnect
m.run( host, ports )


#class HandleTemplates
#
#  Dir.chdir( dir )
#  Dir.glob( '*.tpl' ).select { |f| File.directory? f }
#
#end
