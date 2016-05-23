#!/bin/bash

. config.rc

docker build --no-cache --tag=${TAG_NAME} .

# EOF
