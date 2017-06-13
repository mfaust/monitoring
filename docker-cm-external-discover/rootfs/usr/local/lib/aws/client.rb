
require 'aws-sdk'
require 'digest/md5'

require_relative '../logging'
require_relative '../monkey'

module Aws

  module Ec2

    class Client

      include Logging

      def initialize( settings = {} )

        @region  = settings.dig(:aws, :region) || 'us-east-1'

        begin

          Aws.config.update( { region: @region } )

          @awsClient = Aws::EC2::Client.new()
        rescue => e

          raise e
        end

      end


      def instances( params = {} )

        region  = params.dig(:region) || @region
        filter  = params.dig(:filter)
        domain  = params.dig(:domain) || 'monitoring'
        result  = Array.new()

        if( filter == nil )
          logger.error( 'the param \'filter\' can not be nil!' )
          return result
        end

        logger.debug( filter )

        begin

          instances = @awsClient.describe_instances( filters: filter )

          instances.reservations.each do |res|

            res.instances.each do |inst|

#               logger.debug(inst)

              iid     = inst.dig(:instance_id)
              istate  = inst.dig(:state).name
              ilaunch = inst.dig(:launch_time)
              iip     = inst.dig(:private_ip_address)
              ifqdn   = inst.dig(:private_dns_name)
              itags   = inst.dig(:tags)

              if( itags )

                tags = Array.new()
                itags.each do |t|
                  tags << { t.dig(:key).downcase => t.dig(:value) }
                end
              end

              tags = tags.reduce( :merge )
              tags = Hash[tags.sort]

#               logger.debug( JSON.pretty_generate( tags ) )

              if( tags.key?('monitoring-services') )
                tags['services'] = tags.delete('monitoring-services')
              end

              useableTags = tags.filter( 'customer', 'environment', 'tier', 'name', 'services' )

              if( useableTags.key?('services') )
                useableTags['services'] = useableTags['services'].split(',')
              else
                useableTags['services'] = []
              end

              entry = {
                'fqdn'        => "#{iid}.#{domain}",
                'name'        => iid,
                'state'       => istate,
                'uid'         => iid,
                'region'      => region,
                'launch_time' => ilaunch,
                'dns'         => {
                  'ip'    => iip,
                  'short' => ifqdn.split('.').first,
                  'fqdn'  => ifqdn
                },
                'tags'        => useableTags
              }

              checksum = Digest::MD5.hexdigest( entry.to_s )

              entry['checksum'] = checksum

              result << entry
            end
          end

        rescue => e

          raise e
        end

#         logger.debug( JSON.pretty_generate( result ) )

        return result

      end

    end
  end
end

