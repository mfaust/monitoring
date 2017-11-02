
module DataCollector

  class Config

    include Logging

    attr_accessor :config
    attr_accessor :jolokiaApplications

    def initialize( settings = {} )

      applicationConfig  = settings.dig( :configFiles, :application )
      serviceConfig      = settings.dig( :configFiles, :service )

      @config             = nil
      jolokiaApplications = nil

      appConfigFile  = File.expand_path( applicationConfig )

      begin

        if( File.exist?( appConfigFile ) )

          @config      = YAML.load_file( appConfigFile )

          @jolokiaApplications = @config.dig( 'jolokia', 'applications' )

        else
          logger.error( sprintf( 'Application Config File %s not found!', appConfigFile ) )

          raise( sprintf( 'Application Config File %s not found!', appConfigFile ) )

        end
      rescue => e

      end

    end

  end

end


