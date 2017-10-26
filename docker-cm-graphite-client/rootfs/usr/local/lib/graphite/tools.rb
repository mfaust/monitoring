
module Graphite

  module Tools

    def node_tag(host )

      if( @identifier != nil )
        @identifier
      else
        host
      end
    end

  end

end

