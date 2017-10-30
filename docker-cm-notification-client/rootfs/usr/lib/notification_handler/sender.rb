
module NotificationHandler

  module Sender

    def send( payload )

      payload = JSON.parse( payload ) if( payload.is_a?(String) )
      payload['timestamp'] = Time.now.to_i

      payload
    end

    def store( data )




    end

  end
end
