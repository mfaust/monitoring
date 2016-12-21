#!/usr/bin/ruby
#
# 06.12.2016 - Bodo Schulz
#
#
# v0.0.1

# -----------------------------------------------------------------------------

require 'logger'
require 'json'
require 'yaml'
require 'fileutils'
require 'dalli'
require 'resolve/hostname'
require 'rest-client'

require '/home/bschulz/src/cm-xlabs/monitoring/docker-cm-monitoring/rootfs/usr/local/lib/database'

# -----------------------------------------------------------------------------

class Test


  def initialize( settings )

    @log = Logger.new( STDOUT )
    @log.level      = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter  = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end
  end

  def run()

    @database         = Database::SQLite.new()


    hostInfo = hostResolve( host )

    ip            = hostInfo[:ip]    ? hostInfo[:ip]    : nil # dnsResolve( host )
    shortHostName = hostInfo[:short] ? hostInfo[:short] : nil # dnsResolve( host )
    longHostName  = hostInfo[:long]  ? hostInfo[:long]  : nil # dnsResolve( host )

    @log.info( sprintf( ' Host      : %s', host ) )
    @log.info( sprintf( ' IP        : %s', ip ) )
    @log.info( sprintf( ' short Name: %s', shortHostName ) )
    @log.info( sprintf( ' long Name : %s', longHostName ) )

    sql = "INSERT OR REPLACE INTO dns ( ip, longname, shortname )
             VALUES ( '#{ip}', '#{longHostName}', '#{shortHostName}'
               COALESCE( ( SELECT ip FROM dns WHERE ip = '#{ip}' ), 'Benchwarmer' )
             )"

    @log.debug( sql )

    @database.exec( sql )


  end


end


# EOF
