
module Graphite

  module Tools

    def nodeTag( host )

      if( @identifier != nil )
        return @identifier
      else
        return host
      end
    end

  end

end

