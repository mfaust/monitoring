#!/usr/bin/ruby

require 'sqlite3'
require 'socket'
require 'timeout'

# -------------------------------------------------------------------------------------------------------------------

class Discover

  def initialize( host = nil, ports = [] )

    createHostOnDatabase( host )

    open = false

    ports.each do |p|

      if port_open?( host, p )
        puts "[OPEN]: Port #{p} is open on host #{host}"
        open = true
      else
        puts "[NOT OPEN]: Port #{p} is not open on host #{host}"
        open = false
      end

      insertIntoDB( host, p, open )
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


Host  = '192.168.252.100'
Ports = [3306,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,$


d = new Discover( Host, Ports )


class handleTemplates

  Dir.chdir( dir )
  Dir.glob( '*.tpl' ).select { |f| File.directory? f }

end


















Class Logging

  def initialize

    file = File.open( '/tmp/monitoring.log', File::WRONLY | File::APPEND | File::CREAT )
#    @log = Logger.new( file, 'weekly', 1024000 )
    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end
  end

end





# -------------------------------------

def Database()

#  begin

  db = SQLite3::Database.new ":memory:"
  puts db.get_first_value 'SELECT SQLITE_VERSION()'

#  db.execute "CREATE TABLE IF NOT EXISTS hosts  ( id INTEGER PRIMARY KEY, name string, ip string, alive int )"
#  db.execute "CREATE TABLE IF NOT EXISTS ports  ( id INTEGER PRIMARY KEY, id_host int, port int )"
#  db.execute "CREATE TABLE IF NOT EXISTS checks ( id INTEGER PRIMARY KEY, id_host int, id_ports int, checks text )"
#
#
#    id = db.last_insert_row_id
#    puts "The last id of the inserted row is #{id}"
#
#    stm = db.prepare "SELECT * FROM Cars LIMIT #{id}"
#    rs = stm.execute
#
#    rs.each do |row|
#      puts row.join "\s"
#    end
#
#    stm.close
#
#    id = 5
#
#    stm = db.prepare "SELECT * FROM Cars WHERE Id=?"
#    stm.bind_param 1, id
#    rs = stm.execute
#
#    row = rs.next
#
#    puts row.join "\s"
#
#  rescue SQLite3::Exception => e
#
#      puts "Exception occurred"
#      puts e
#
#  ensure
#
#    stm.close if stm
#
#    db.close if db
#
#  end
end

# -------------------------------------

def checkPorts()

  def port_open?(ip, port, seconds=2)
    # => checks if a port is open or not on a remote host
    Timeout::timeout(seconds) do
      begin
        TCPSocket.new(ip, port).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        false
      end
    end
    rescue Timeout::Error
      false
  end

  HOST = '192.168.0.20'
  PORTS= [3306,28017,38099,40099,40199,40299,40399,40499,40599,40699,40799,40899,40999,41099,41199,41299,41399,42099,42199,42299,42399,42499,42599,42699,42799,42899,42999,43099,44099,45099,46099,47099,48099,49099]


  PORTS.each do |p|

    if port_open?(HOST, p)
      puts "[OPEN]: Port #{p} is open on host #{HOST}"
    else
      puts "[NOT OPEN]: Port #{p} is not open on host #{HOST}"
    end

  end

end

# -------------------------------------
# http://stackoverflow.com/questions/10919287/make-this-http-post-request-in-ruby

def jolokia1()

  require 'net/http'
  require 'json'
  require 'uri'

  uri          = URI.parse( "http://jolokia:8080" )
  http         = Net::HTTP.new(uri.host, uri.port)

  request      = Net::HTTP::Post.new( "/jolokia/" )
  request.add_field('Content-Type', 'application/json')

  response     = http.request(request)

  puts response.code
  puts response.body.to_json

end

# -------------------------------------
# https://github.com/towerhe/jolokia

def jolokia()

  require 'jolokia'

  jolokia = Jolokia.new(url: 'http://jolokia:8080/jolokia')

  response = jolokia.request(
    :post,
    type: 'read',
    mbean: 'java.lang:type=Memory',
    attribute: 'HeapMemoryUsage'
  )

  puts response

end

# -------------------------------------

def replaceWord()

  # load the file as a string
  data = File.read("hello.txt")
  # globally substitute "install" for "latest"
  filtered_data = data.gsub("install", "latest")
  # open the file for writing
  File.open("hello.txt", "w") do |f|
    f.write(filtered_data)
  end

end

# -------------------------------------


unless ARGV.empty?

  ARGV.each do|a|
    puts "Argument: #{a}"
  end


  if ARGV.first.start_with?("-")
    case ARGV.shift  # shift takes the first argument and removes it from the array
    when '-v', '--verbose'
      verbose = true
    when '--version'
      puts "1.0"
      exit 0         # exit script with status 0 (all OK)
    end
  end
end
if verbose
  puts "Files #{ARGV.join(', ')} contains #{ARGF.readlines.count} lines."
else
  puts "#{ARGF.readlines.count}"
end

# -------------------------------------

SQL
table
 hosts : id, name, ip, alive
 ports : id, id_host. port
 checks: id, id_host, id_ports, checks


add     # add host
list    # list hosts
delete  # delete host
reuse   # read database and create new json files








