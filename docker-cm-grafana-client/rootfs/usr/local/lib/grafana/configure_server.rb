
require 'yaml'

class CMGrafana

  module ConfigureServer

    def configure_server( params )

      config_file = params.dig(:config_file)

      if( !config_file.nil? && File.file(config_file) )

        begin

          @config      = YAML.load_file( config_file )

        rescue Exception

          logger.error( 'wrong result (no yaml)')
          logger.error( "#{$!}" )

          raise( 'no valid yaml File' )
          exit 1
        end
      else
        logger.error( sprintf( 'Config File %s not found!', config_file ) )
      end



    end

  end

end

