#!/bin/bash -e

docker build -f docker/Dockerfile -t gonitro/spacesuit .
if [[ $? -ne 0 ]]; then
	echo "Something went wrong, aborting container build" >&2
	exit
fi

# Either use the Travis tag (shortened), or get it from git
TAG=${TRAVIS_COMMIT:-`git rev-parse --short HEAD`}
TAG=${TAG::7}

docker tag gonitro/spacesuit gonitro/spacesuit:latest
docker tag gonitro/spacesuit gonitro/spacesuit:$TAG
docker push gonitro/spacesuit:$TAG
docker push gonitro/spacesuit:latest
