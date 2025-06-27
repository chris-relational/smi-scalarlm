#!/usr/bin/env bash

# Usage
# $ remove-image.sh <image-name>
# 
# 1. stop and delete all running containers
# 2. Remobe the image name <image-name> 

# e exit on first failure
# x all executed commands are printed to the terminal
# u unset variables are errors
# a export all variables to the environment
# E any trap on ERR is inherited by shell functions
# -o pipefail | produces a failure code if any stage fails
set -Eeuoxa pipefail

# Stop all running containers and delete them
if [[ -z ${image_tag:=$1} ]]; then
    echo "No image name provided. Exiting"
    exit 1
fi

# We don't know the image's container dependencies so we stop & delete all containers
containers="$(docker ps -aq)"
if [[ -n $containers ]]; then
    echo $containers | xargs docker container stop 
    echo $containers | xargs docker rm
fi

docker images | python -c '
from sys import stdin
for line in stdin:
   fields = line.strip().split()
   print(fields[0], fields[1], sep=":")
' | grep "${image_tag}" | xargs docker rmi

