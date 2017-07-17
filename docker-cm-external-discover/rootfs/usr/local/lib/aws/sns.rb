
require 'aws-sdk'
require 'digest/md5'

require_relative '../logging'
require_relative '../monkey'

module Aws

  module Sns

    class Client

      include Logging

      def initialize( settings = {} )

        @region  = settings.dig(:aws, :region) || 'us-east-1'
        @sns     = Aws::SNS::Client.new(region: @region)

#        begin
#
#          Aws.config.update( { region: @region } )
#
#          @awsClient = Aws::EC2::Client.new()
#        rescue => e
#
#          raise e
#        end

      end


      def create_subscription( params = {} )

        region     = params.dig(:region)  || @region
        account_id = params.dig(:account_id)
        topic      = params.dig(:topic)
        protocol   = params.dig(:protocol)
        endpoint   = params.dig(:endpoint)

        sns       = Aws::SNS::Resource.new( region: region )

        topic     = sns.topic( sprintf( 'arn:aws:sns:%s:%s:%s', region, account_id, topic ) ) #  'arn:aws:sns:us-west-2:123456789:MyGroovyTopic')

        sub = topic.subscribe({
          protocol: protocol,
          endpoint: endpoint
        })

        logger.debug( sub.arn )


      end


      def send_message( params = {} )

        # aws sns publish --topic-arn "arn:aws:sns:us-east-1:450225884721:app-monitoring" --message file://message.txt

        region     = params.dig(:region)  || @region
        account_id = params.dig(:account_id)
        topic      = params.dig(:topic)
        subject    = params.dig(:subject)
        message    = params.dig(:message)

        begin

          resp       = @sns.publish({
            target_arn: sprintf( 'arn:aws:sns:%s:%s:%s', region, account_id, topic ),
            message: message,
            subject: subject
          })

#           logger.debug( resp.class.to_s )
#           logger.debug( resp )
#           logger.debug( resp.data.message_id )
#           logger.debug( resp.error)
#           logger.debug( resp.successful? )

          logger.debug( format('successful send with id: %s', resp.data.message_id ) )

        rescue => e

          raise(e)

        end
      end


      def show_topics()

#        @sns.show_topic( )

#         region    = params.dig(:region)  || @region
#
#         sns       = Aws::SNS::Resource.new( region: region )
#
#         sns.topics.each do |topic|
#           logger.debug( topic.arn )
#         end
      end


    end

  end

end

