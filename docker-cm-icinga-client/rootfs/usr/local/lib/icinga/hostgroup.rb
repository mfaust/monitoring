
To add hostgroup :

curl -k -s -u icingaadmin:icinga 'https://localhost:5665/v1/objects/hostgroups/testgrp' -X PUT -d '{ "attrs": { "name" : "testgrp" ,"display_name" : "testgrp" , "state_loaded" :true }}'

To add host :

curl -k -s -u icingaadmin:icinga 'https://localhost:5665/v1/objects/hosts/8.8.8.8' -X PUT -d '{ "templates": [ "generic-host" ], "attrs": { "address": "8.8.8.8" , "groups" : [ "testgrp" ]} }'

