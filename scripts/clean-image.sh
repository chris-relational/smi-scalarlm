#!/usr/bin/env bash

# Usage
# $ clean-image.sh <image-name>

set -e

# Stop all running containers and delete them
image_tag=$1
if [[ -z $image_tag ]]; then
    echo "No image name provided. Exiting"
    exit 1
fi

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

