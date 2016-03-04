#/bin/bash

docker create \
  --volume=/opt/chefdk \
  --name docker-chefdk \
  ${USER}-docker-chefdk \
  /bin/true