#
#


class JolokiaTemplate

  def self.singleTemplate( params = {} )

    mbean       = params['mbean']
    server_name = params['server_name']
    server_port = params['server_port']

    target = {
      "type" => "read",
      "mbean" => "#{mbean}",
      "target" => {
        "url" => "service:jmx:rmi:///jndi/rmi://#{server_name}:#{server_port}/jmxrmi",
      }
    }

    attributes = []

    if( params['attributes'] != nil )
      params['attributes'].split(',').each do |t|
        attributes.push( t.to_s )
      end

      target['attribute'] = attributes
    end

    return target

  end

end
