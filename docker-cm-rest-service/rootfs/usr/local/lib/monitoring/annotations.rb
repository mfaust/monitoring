
module Monitoring

  include Logging

  module Annotations

    def annotation( params ) #host, payload )

      logger.debug( "annotation( #{params} )" )

      dns   =  params.dig(:dns )

      ip    = dns.dig(:ip) unless( dns.nil? )
      short = dns.dig(:short) unless( dns.nil? )
      fqdn  = dns.dig(:fqdn) unless( dns.nil? )

      host    = params.dig(:host)
      payload = params.dig(:payload)

      #logger.debug( payload.class.to_s )

      payload = JSON.parse(payload) if( payload.is_a?(String) )
      payload = payload.deep_symbolize_keys

      logger.debug( "payload: #{payload}" )

      if( dns.nil? )
        ip, short, fqdn = ns_lookup( host )
      end

      logger.debug( "ip  : #{ip}" )
      logger.debug( "fqdn: #{fqdn}" )

      status  = 500
      message = 'initialize error'

      result  = Hash.new
      hash    = Hash.new

      if( host.size == 0 && payload.size == 0 )
        return JSON.pretty_generate( status: 404, message: 'missing arguments for annotations' )
      end

      payload         = JSON.parse( payload ) if( payload.is_a?( String ) )

      logger.debug( JSON.pretty_generate( payload ) )

      command      = payload.dig(:command)
      argument     = payload.dig(:argument)
      message      = payload.dig(:message)
      description  = payload.dig(:description)
      tags         = payload.dig(:tags)  || []
      config       = payload.dig(:config)

      if( command == 'create' || command == 'remove' )
  #     example:
  #     {
  #       "command": "create"
  #     }
  #
  #     {
  #       "command": "destroy"
  #     }

        message     = nil
        description = nil
        tags        = []

        params = {
          :cmd     => command,
          :node    => host,
          :queue   => 'mq-graphite',
          :payload => {
            :timestamp => Time.now().to_i,
            :config    => config,
            :fqdn      => fqdn,
            :node      => host,
            :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
          },
          :prio => 0
        }

        logger.debug(params)

        self.messageQueue(params)

      elsif( command == 'loadtest' && ( argument == 'start' || argument == 'stop' ) )

  #     example:
  #     {
  #       "command": "loadtest",
  #       "argument": "start"
  #     }
  #
  #     {
  #       "command": "loadtest",
  #       "argument": "stop"
  #     }

        message     = nil
        description = nil
        tags        = []

        self.messageQueue({
          :cmd     => 'loadtest',
          :node    => host,
          :queue   => 'mq-graphite',
          :payload => {
            :timestamp => Time.now().to_i,
            :config    => config,
            :fqdn      => fqdn,
            :argument  => argument,
            :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
          },
          :prio => 0
        })

      elsif( command == 'deployment' )

  #     example:
  #     {
  #       "command": "deployment",
  #       "message": "version 7.1.50",
  #       "tags": [
  #         "development",
  #         "git-0000000"
  #       ]
  #     }
        description = nil
        self.messageQueue({
          :cmd => 'deployment',
          :node => host,
          :queue => 'mq-graphite',
          :payload => {
            :timestamp => Time.now().to_i,
            :config    => config,
            :fqdn      => fqdn,
            :message   => message,
            :tags      => tags,
            :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
          },
          :prio => 0
        })

      else
  #     example:
  #     {
  #       "command": "",
  #       "message": "date: 2016-12-24, last-cristmas",
  #       "description": "never so ho-ho-ho",
  #       "tags": [
  #         "development",
  #         "git-0000000"
  #       ]
  #     }
        self.messageQueue({
          :cmd => 'general',
          :node => host,
          :queue => 'mq-graphite',
          :payload => {
            :timestamp => Time.now().to_i,
            :config    => config,
            :fqdn      => fqdn,
            :message   => message,
            :tags      => tags,
            :description => description,
            :dns       => {:ip => ip, :short => short, :fqdn => fqdn }
          },
          :prio => 0
        })

      end

      status    = 200
      message   = 'annotation succesfull created'

      return JSON.pretty_generate( {
        :status  => status,
        :message => message
      } )

    end

  end

end
