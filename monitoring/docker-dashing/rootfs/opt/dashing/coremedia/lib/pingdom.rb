#
# lib/pingdom.rb
# Library for Dashing Job to poll Pingdom
#
# Version 0.1.0
#
# (c) 2016 Coremedia - Bodo Schulz <bodo.schulz@coremedia.com>

# ----------------------------------------------------------------------------

require 'pingdom-faraday'
require 'rest-client'
require 'cgi'
require 'json'
require 'logger'

# ----------------------------------------------------------------------------

class PingDom

  def initialize( api_key, user, password )

    file = File.open( '/tmp/dashing-pingdom.log', File::WRONLY | File::APPEND | File::CREAT )
    @log = Logger.new( file, 'weekly', 1024000 )
#    @log = Logger.new( STDOUT )
    @log.level = Logger::DEBUG
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end


    begin
      if( api_key.empty? or user.empty? or password.empty? )
        @log.error( 'Environment Variable to access pingdom ReST API are missing!')
        exit 1
      else
        @api_key = api_key
        @user = user
        @password = password
      end
    end

  end

  def data

    client = Pingdom::Client.new( :username => @user, :password => @password, :key => @api_key )

    if client.checks

      checks = client.checks.map { |check|

        if check.status == 'up'
          color = 'green'
        else
          color = 'red'
        end

        last_response = check.last_response_time.to_s + " ms"

        {
          name: check.name,
          state: color,
          lastRepsonseTime: last_response
        }
      }

      checks.sort! { |a, b| [a['name'], a['last_response_time']] <=> [b['name'], b['last_response_time']] }
#      checks.sort_by { |check| check['name'] }

      return checks

#      send_event('pingdom', { checks: checks })
    end
#      return client.checks
  end

end

