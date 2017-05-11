
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


        begin

          instances = @awsClient.describe_instances( filters: filter )

          instances.reservations.each do |res|

            res.instances.each do |inst|

              iid     = inst[:instance_id]
              istate  = inst[:state].name
              ilaunch = inst[:launch_time]
              iip     = inst[:private_ip_address]
              ifqdn   = inst[:private_dns_name]
              itags   = inst[:tags]

              if( itags )

                tags = Array.new()
                itags.each do |t|
                  tags << { t[:key] => t[:value] }
                end
              end

              tags = tags.reduce( :merge )
              logger.debug(tags)
              logger.debug(tags.class.to_s)
              tags = Hash[tags.sort]

              useableTags = tags.filter( 'customer', 'environment', 'tier' )

              entry = {
                'fqdn'        => "#{iid}.#{domain}",
                'name'        => iid,
                'state'       => istate,
                'uid'         => iid,
                'launch_time' => ilaunch,
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

        puts JSON.pretty_generate( result )

        return result

      end

    end

  end

end

