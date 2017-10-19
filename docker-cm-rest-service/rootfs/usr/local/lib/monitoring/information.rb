module Monitoring

  module Information

    # get informations for one or all nodes back
    #
    def nodeInformations( params = {} )

#       logger.debug( "nodeInformations( #{params} )" )

      host            = params.dig(:host)
      status          = params.dig(:status) || [ Storage::MySQL::ONLINE, Storage::MySQL::PREPARE ]
      fullInformation = params.dig(:full)   || false

      ip              = nil
      short           = nil
      fqdn            = nil

      result  = Hash.new()

      if( host != nil )

        ip, short, fqdn = self.nsLookup( host )

        if( ip == nil && short == nil && fqdn == nil )

          return nil
        end

        params = { :ip => ip, :short => short, :fqdn => fqdn, :status => status }
      else

        params = { :status => status }
      end

      # get nodes with ONLINE or PREPARE state
      #
      nodes = @database.nodes( params )

      if( nodes.is_a?( Array ) && nodes.count != 0 )

        nodes.each do |n|

          if( ip == nil && short == nil && fqdn == nil )

            ip, short, fqdn = self.nsLookup( n )

            if( ip == nil && short == nil && fqdn == nil )

              result = {
                :status  => 400,
                :message => sprintf( 'Host \'%s\' are not available (DNS Problem)', n )
              }

              logger.warn( result )

              next
            end

          end

          result[n.to_s] ||= {}

          # DNS data
          #
          result[n.to_s][:dns] ||= { 'ip' => ip, 'short' => short, 'fqdn' => fqdn }

          status  = @database.status( { :ip => ip, :short => short, :fqdn => fqdn } )
          # {"ip"=>"192.168.252.100", "name"=>"blueprint-box", "fqdn"=>"blueprint-box", "status"=>"online", "creation"=>2017-06-07 11:07:57 +0000}

          created = status.dig('creation')
          message = status.dig('status')

          # STATUS data
          #
          result[n.to_s][:status] ||= { 'created' => created, 'status' => message }

          hostConfiguration = @database.config( { :ip => ip, :short => short, :fqdn => fqdn } )

          if( hostConfiguration != nil )
            result[n.to_s][:custom_config] = hostConfiguration
          end

          # get discovery data
          #
          discoveryData = @database.discoveryData( { :ip => ip, :short => short, :fqdn => fqdn } )

          if( discoveryData != nil )

#             logger.debug( discoveryData.class.to_s )

            discoveryData.each do |a,d|

#               logger.debug(a)
#               logger.debug( d.class.to_s )
              if(d.is_a?(String))
                d = JSON.generate(d)
              end

              d.reject! { |k| k == 'application' }
              d.reject! { |k| k == 'template' }
            end

            result[n.to_s][:services] ||= discoveryData

          end

          # realy needed?
          #
            if( fullInformation != nil && fullInformation == true )

              # get data from external services
              #
              self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-grafana' , :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )
              self.messageQueue( { :cmd => 'info', :node => n, :queue => 'mq-icinga'  , :prio => 1, :payload => {}, :ttr => 1, :delay => 0 } )

              sleep( 1 )

              grafanaStatus   = Hash.new()
              icingaStatus    = Hash.new()

              for y in 1..4

                r      = @mqConsumer.getJobFromTube('mq-grafana-info')

#                 logger.debug( r.dig( :body, 'payload' ) )

                if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

                  grafanaStatus = r
                  break
                else
#                   logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-grafana-info', y ) )
                  sleep( 2 )
                end
              end

              for y in 1..4

                r      = @mqConsumer.getJobFromTube('mq-icinga-info')

#                 logger.debug( r.dig( :body, 'payload' ) )

                if( r.is_a?( Hash ) && r.count != 0 && r.dig( :body, 'payload' ) != nil )

                  icingaStatus = r
                  break
                else
#                   logger.debug( sprintf( 'Waiting for data %s ... %d', 'mq-icinga-info', y ) )
                  sleep( 2 )
                end
              end

              if( grafanaStatus )
                grafanaStatus = grafanaStatus.dig( :body, 'payload' ) || {}
                result[n.to_s][:grafana] ||= grafanaStatus
              end

              if( icingaStatus )
                icingaStatus = icingaStatus.dig( :body, 'payload' ) || {}
                result[n.to_s][:icinga] ||= icingaStatus
              end
            end


          ip    = nil
          short = nil
          fqdn  = nil
        end
      end

      return result

    end

  end
end
