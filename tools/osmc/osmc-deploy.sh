#!/usr/bin/env bash

SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`

test -d ${SCRIPTPATH}/maven-repo || (echo "maven repo missing at ${SCRIPTPATH}/maven-repo" && exit 1)
test -d /tmp/maven-repo || ln -s $SCRIPTPATH/maven-repo /tmp/maven-repo
test -f ${SCRIPTPATH}/content-users.zip || echo "content-users.zip missing in deployment archive, recipe blueprint-dev-tooling::content won't work"
test -f /tmp/content-users.zip || ln -s $SCRIPTPATH/content-users.zip /tmp/content-users.zip

CHEF_CMD="chef-solo --config ${SCRIPTPATH}/chef-repo/.chef/solo.rb"

function select_file() {

PS3="$prompt "
select opt in "${options[@]}"; do
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        eval $1=$opt
        break
    else
        echo "Invalid option. Try another one."
    fi
done
}

CHEF_ENV="development"
CHEF_NODE_CONFIG="cms-1710"

#prompt="Please select an environment:"
#options=( $(find ${SCRIPTPATH}/chef-repo/environments/*.json -maxdepth 1 | xargs -I file basename file .json | xargs) )
# choosing node file
#select_file CHEF_ENV
CHEF_CMD+=" --environment ${CHEF_ENV}"

#prompt="Please select a node config:"
#options=( $(find ${SCRIPTPATH}/chef-repo/nodes/*.json -maxdepth 1 | xargs -I file basename file .json | xargs) )
# choosing environment
#select_file CHEF_NODE_CONFIG
CHEF_CMD+=" --json-attributes ${SCRIPTPATH}/chef-repo/nodes/${CHEF_NODE_CONFIG}.json"

echo "Starting Chef Solo with environment ${CHEF_ENV} from node configuration ${CHEF_NODE_CONFIG}"
${CHEF_CMD}
rm -f /tmp/maven-repo /tmp/content-users.zip
echo "Open http://overview.${HOSTNAME} in your browser to visit the overview"

