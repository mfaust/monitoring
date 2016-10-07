#!/usr/bin/ruby

require 'optparse'
require 'json'
require 'logger'

require_relative '/usr/local/lib/mbean.rb'

# ---------------------------------------------------------------------------------------

class Integer
  def to_filesize
    {
      'B'  => 1024,
      'KB' => 1024 * 1024,
      'MB' => 1024 * 1024 * 1024,
      'GB' => 1024 * 1024 * 1024 * 1024,
      'TB' => 1024 * 1024 * 1024 * 1024 * 1024
    }.each_pair { |e, s| return "#{(self.to_f / (s / 1024)).round(2)} #{e}" if self < s }
  end
end


class Icinga2Check

  STATE_OK        = 0
  STATE_WARNING   = 1
  STATE_CRITICAL  = 2
  STATE_UNKNOWN   = 3
  STATE_DEPENDENT = 4

  def readConfig( service )

    file = '/etc/cm-icinga2.yaml'

    usePercent = nil
    warning    = nil
    critical   = nil

    if( File.exist?( file ) )

      begin

        config  = YAML.load_file( file )

        service = config[service] ? config[service] : nil

        if( service != nil )
          usePercent = service['usePercent'] ? service['usePercent'] : nil
          warning    = service['warning'] ? service['warning']       : nil
          critical   = service['critical'] ? service['critical']     : nil
        end
      rescue YAML::ParserError => e

        @log.error( 'wrong result (no yaml)')
        @log.error( e )
      end
    end

    return {
      :usePercent => usePercent,
      :warning    => warning,
      :critical   => critical
    }

  end


  def logger()

#    logFile      = sprintf( '/var/log/icinga2check.log',  )
#    file         = File.open( logFile, File::WRONLY | File::APPEND | File::CREAT )
#    file.sync    = true
#    @log      = Logger.new( file, 'weekly', 1024000 )

    log = Logger.new( STDOUT )
    log.level = Logger::DEBUG
    log.datetime_format = "%Y-%m-%d %H:%M:%S::%3N"
    log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    return log

  end


  def memcache()

    memcacheHost     = ENV['MEMCACHE_HOST'] ? ENV['MEMCACHE_HOST'] : nil
    memcachePort     = ENV['MEMCACHE_PORT'] ? ENV['MEMCACHE_PORT'] : nil
    supportMemcache  = false

    if( memcacheHost != nil && memcachePort != nil )

      # enable Memcache Support

      require 'dalli'

      memcacheOptions = {
        :compress   => true,
        :namespace  => 'monitoring',
        :expires_in => 0
      }

      mc = Dalli::Client.new( sprintf( '%s:%s', memcacheHost, memcachePort ), memcacheOptions )

      supportMemcache = true

      MBean.memcache( memcacheHost, memcachePort )

      return mc
    end

    return false

  end


  def shortHostname( hostname )

    return hostname.split( '.' ).first

  end


end
