
class CMGrafana

  module CoreMedia

    module Annotations

      # add standard annotations to all Templates
      #
      #
      def add_annotations(template_json )

        # add or overwrite annotations
        annotations = '
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
                "tags": [
                  "%TAG%",
                  "created"
                ],
                "type": "tags"
              },
              {
                "datasource": "-- Grafana --",
                "enable": true,
                "hide": false,
                "iconColor": "rgb(227, 57, 12)",
                "limit": 10,
                "name": "destoyed",
                "showIn": 0,
                "tags": [
                  "%TAG%",
                  "destoyed"
                ],
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
                "tags": [
                  "%TAG%",
                  "loadtest"
                ],
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
                "tags": [
                  "%TAG%",
                  "deployment"
                ],
                "type": "tags"
              }
            ]
          }
        '

        if( template_json.is_a?( String ) )
          template_json = JSON.parse( template_json )
        end

        annotation = template_json.dig( 'dashboard', 'annotations' )

        if( annotation != nil )
          template_json['dashboard']['annotations'] = JSON.parse( annotations )
        end

        template_json

      end

    end

  end
end

