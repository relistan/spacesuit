#!/bin/sh

docker build -f docker/Dockerfile -t gonitro/spacesuit .
if [[ $? -ne 0 ]]; then
	echo "Something went wrong, aborting container build" >&2
	exit
fi

TAG=`git rev-parse --short HEAD`
docker tag gonitro/spacesuit gonitro/spacesuit:latest
docker tag gonitro/spacesuit gonitro/spacesuit:$TAG
docker push gonitro/spacesuit:$TAG
docker push gonitro/spacesuit:latest
