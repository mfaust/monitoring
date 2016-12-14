#!/usr/bin/ruby
#
# 13.12.2016 - Bodo Schulz
#
#
# v0.0.1

# -----------------------------------------------------------------------------

require 'sqlite3'

# -----------------------------------------------------------------------------

# Monkey patches

class Array
  def compare( comparate )
    to_set == comparate.to_set
  end
end

# -----------------------------------------------------------------------------



module Database

  class SQLite

    attr_accessor :database

    def initialize( params = {} )

      @cacheDirectory    = params[:cacheDirectory] ? params[:cacheDirectory] : '/var/cache/monitoring'
      @logDirectory      = params[:logDirectory]   ? params[:logDirectory]   : '/var/log/monitoring'

      logFile        = sprintf( '%s/database.log', @logDirectory )

      file           = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
      file.sync      = true
      @log           = Logger.new( file, 'weekly', 1024000 )
#      @log = Logger.new( STDOUT )
      @log.level     = Logger::DEBUG
      @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
      @log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
      end

      self.createTables()
    end

    def createTables()

      begin
        @database = SQLite3::Database.new( sprintf( '%s/database.db', @cacheDirectory ) )

        @log.info( @database.get_first_value( 'SELECT SQLITE_VERSION()' ) )

        @database.transaction()
        @database.execute( 'CREATE TABLE IF NOT EXISTS hosts ( shortname string not null PRIMARY KEY, created string not null, updated string not null, status varchar(10) )' )
        @database.execute( 'create table IF NOT EXISTS dns ( ip varchar(16) not null, longname varchar(240), shortname varchar(60), CONSTRAINT constraint_name unique( ip, shortname ) )' )
        @database.commit()

      rescue SQLite3::Exception => e
#        puts e.errno
        @log.error( e.error )
        @database.rollback()

#      ensure
#        if @database
#          @database.close
#        end
      ensure
        if( @database )
          @database.close()
        end
      end

    end


    def exec( sql )

      



    end

  end

end
