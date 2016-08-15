#
#
#

class CollectdOutputGraphite

  def self.output( host, service, data )

    puts( host )
    puts( service )
    puts( JSON.pretty_generate( data ) )

    data.each do |d|


  end

end
