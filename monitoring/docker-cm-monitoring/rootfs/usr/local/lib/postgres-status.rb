#
#
#

require 'pg'


class  postgresStatus

  attr_accessor :postgresHost, :postgresPort, :postgresUser, :postgresUser

  def initialize( settings = {} )

    @logDirectory      = settings['log_dir']   ? settings['log_dir']   : '/tmp'
    @postgresHost         = settings['postgresHost'] ? settings['postgresHost'] : 'localhost'
    @postgresPort         = settings['postgresPort'] ? settings['postgresPort'] : 5432
    @postgresUser         = settings['postgresUser'] ? settings['postgresUser'] : 'root'
    @postgresPass         = settings['postgresPass'] ? settings['postgresPass'] : ''
    @postgresDBName       = settings['postgresDBName'] ? settings['postgresDBName'] : 'test'

    logFile            = sprintf( '%s/postgres-status.log', @logDirectory )

    file      = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync = true
    @log = Logger.new(file, 'weekly', 1024000)
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end


  end

  def connect()

    :dbname => 'test', :port =>  )

    params = {
      :dbname   => @postgresDBName,
      :user     => @postgresUser,
      :port     => @postgresPort,
      :password => @postgresPass
    }

    begin
      @connection = PG::Connection.new( params )
    rescue PG::Error => e
      STDERR.puts "An error occurred #{e}"
      @log.error( sprintf( 'An error occurred '%s\'', e ) )
    end

  end

  def run()

    self.connect()

    begin

      row  = @connection.exec( 'SELECT * from pg_stat_statements' )

#      rows = @sequel[ @mysqlQuery ].to_hash( :Variable_name,:Value )
#      rows = self.valuesToNumeric(rows)
#      rows = self.calculateRelative(rows) if @relative
#      rows = self.scaleValues(rows)
#      output_query(rows) unless first_run && @relative

      @log.debug( row.inspect() )
    rescue Exception => e
      STDERR.puts "An error occurred #{e}"
    end

  end




end
