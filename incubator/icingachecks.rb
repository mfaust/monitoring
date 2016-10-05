#!/usr/bin/ruby

require 'optparse'
require 'json'
require 'logger'

require_relative '/usr/local/lib/mbean.rb'

# ---------------------------------------------------------------------------------------

class Icinga2Check

  STATE_OK        = 0
  STATE_WARNING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  def initialize( settings = {} )

    @host        = settings[:host]        ? settings[:host]        : nil
    @application = settings[:application] ? settings[:application] : nil
    memory       = settings[:memory]      ? settings[:memory]      : nil

    logFile      = sprintf( '/var/log/icinga2check.log',  )
    file         = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
    file.sync    = true
    @log      = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    @memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    @memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil
    @supportMemcache  = false

    MBean.logger( @log )

    if( @memcacheHost != nil && @memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      @mc = Dalli::Client.new( sprintf( '%s:%s', @memcacheHost, @memcachePort ), memcacheOptions )

      @supportMemcache = true

      MBean.memcache( @memcacheHost, @memcachePort )
    end

    @host = self.shortHostname( @host )

  end


  def shortHostname( hostname )

    return hostname.split( '.' ).first

  end


end
