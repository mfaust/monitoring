
require 'aws-sdk'
require 'time'
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

        currentTime = Time.now.to_i

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

              ilaunch = ilaunch.to_i
              launch_time_diff = currentTime - ilaunch

              if( launch_time_diff < 60 ) # add 60 seconds
                logger.debug( "node #{iid} started at #{Time.at(ilaunch + 60).strftime('%Y-%m-%d %H:%M:%S')} (#{Time.at(currentTime).strftime('%Y-%m-%d %H:%M:%S')}) .. skip" )
                next
              end

              if( itags )
                tags = Array.new()
                itags.each do |t|
                  tags << { t.dig(:key).downcase => t.dig(:value) }
                end
              end

              tags = tags.reduce( :merge )
              tags = Hash[tags.sort]

              if( tags.key?('cm_apps') )
                tags['services'] = tags.delete('cm_apps')
              end

              useableTags = tags.filter( 'customer', 'environment', 'tier', 'name', 'services' )

              if( useableTags.key?('services') )
                useableTags['services'] = useableTags['services'].split(' ')
                useableTags['services'] << 'node_exporter'
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

