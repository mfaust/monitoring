#!/bin/bash

CURL="curl http://localhost/api/v2/annotation/moebius-ci-02-moebius-tomcat-0-cms"

xsleep() {
  sleep 20s
}

# old style

echo "old style: host create"
${CURL} --data '{ "command": "create" }'
xsleep

echo "old style: host destroy"
${CURL} --data '{ "command": "destroy" }'
xsleep

echo "old style: loadtest start"
${CURL} --data '{ "command": "loadtest", "argument": "start" }'
xsleep

echo "old style: loadtest stop"
${CURL} --data '{ "command": "loadtest", "argument": "start" }'
xsleep

echo "old style: deployment"
${CURL} --data '{ "command": "deployment", "message": "version 7.1.50", "tags": ["7.1.50"] }'
xsleep

echo ""

# new

echo "new style: host create"
${CURL} --data '{ "host": "create" }'
xsleep

echo "new style: host destroy"
${CURL} --data '{ "host": "destroy" }'
xsleep

echo "new style: monitoring add"
${CURL}  --data '{ "monitoring": "add" }'
xsleep

echo "new style: monitoring remove"
${CURL} --data '{ "monitoring": "remove" }'
xsleep

echo "new style: deployment start"
${CURL} --data '{ "deployment": "start", "message": "version 7.1.50", "tags": ["7.1.50"] }'
xsleep

echo "new style: deployment end"
${CURL} --data '{ "deployment": "end" }'
xsleep

echo "new style: contentimport start"
${CURL} --data '{ "contentimport": "start", "message": "10000 wikipedia article" }'
xsleep

echo "new style: contentimport end"
${CURL} --data '{ "contentimport": "end", "message": "10000 wikipedia article" }'
xsleep

echo "new style: loadtest start"
${CURL} --data '{ "deployment": "start" }'
xsleep

echo "new style: loadtest end"
${CURL} --data '{ "deployment": "end" }'
xsleep

echo "new style: free text"
${CURL} --data '{ "message": "free text annotation" }'

 


# 9387  03.04.2018 08:35:41 curl --silent --request POST --data '{ "message": "free text", "tags": ["importer","start"] }' http://moebius-monitoring.coremedia.vm/api/v2/annotation/moebius-ci-02-moebius-tomcat-0-cms
