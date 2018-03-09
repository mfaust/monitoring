
class CMGrafana

  module CoreMedia

    module Annotations

      # add standard annotations to all Templates
      #
      #
      def add_annotations(template_json)

        # add or overwrite annotations
        annotations = %(
          {
            "list": [
              {
                "datasource": "-- Grafana --",
                "enable": true,
                "hide": false,
                "iconColor": "rgb(93, 227, 12)",
                "limit": 10,
                "name": "created",
                "showIn": 0,
                "tags": [ "<%= short_hostname %>", "created" ],
                "type": "tags"
              },
              {
                "datasource": "-- Grafana --",
                "enable": true,
                "hide": false,
                "iconColor": "rgb(227, 57, 12)",
                "limit": 10,
                "name": "destroyed",
                "showIn": 0,
                "tags": [ "<%= short_hostname %>", "destroyed" ],
                "type": "tags"
              },
              {
                "datasource": "-- Grafana --",
                "enable": true,
                "hide": false,
                "iconColor": "rgb(26, 196, 220)",
                "limit": 10,
                "name": "Load Tests",
                "showIn": 0,
                "tags": [ "<%= short_hostname %>", "loadtest" ],
                "type": "tags"
              },
              {
                "datasource": "-- Grafana --",
                "enable": true,
                "hide": false,
                "iconColor": "rgb(176, 40, 253)",
                "limit": 10,
                "name": "Deployments",
                "showIn": 0,
                "tags": [ "<%= short_hostname %>", "deployment" ],
                "type": "tags"
              }
            ]
          }
        )

        short_hostname           = @short_hostname
        renderer = ERB.new(annotations)
        template = renderer.result(binding)
        annotations = JSON.parse( template ) if( template.is_a?( String ) )

        template_json = JSON.parse( template_json ) if( template_json.is_a?( String ) )
        annotation    = template_json.dig( 'dashboard', 'annotations' )

#         logger.debug( "annotation: #{annotation.size} #{annotation.class.to_s}" )

        begin
          template_json['dashboard']['annotations'] = annotations unless( annotation.nil? )
        rescue => error
          logger.error( error )
        end

        template_json
      end
    end
  end
end

