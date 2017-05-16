#!/bin/bash
set -e
set -o pipefail

function find_in_docker_log {
    CONTAINER_NAME=$1
    TIMEOUT=$2
    SUBSTRING=$3
    COMMAND="docker logs -f $CONTAINER_NAME"
    expect -c "log_user 0; set timeout $TIMEOUT; spawn $COMMAND; expect \"$SUBSTRING\" { exit 0 } timeout { exit 1 }"
}

DOCKER_IMAGE_NAME=flyingtophat/alpr
CONTAINER_NAME=alpr_test
TIMEOUT=10

echo "TEST 1 - Assert number found"
IMAGE_NAME=single_horizontal.jpg
docker run --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME http://127.0.0.1/ --verbose \
      --interval 1

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "WR62XDF"
TEST_RESULT=$?

docker rm -f $CONTAINER_NAME
if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi


echo "TEST 2 - Assert number found after prewarp applied"
IMAGE_NAME=multiple_rotated.jpg
docker run --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME http://127.0.0.1/ --verbose \
      --interval 1 \
      --preprocess planar,429.000000,300.000000,-0.000000,0.000000,0.670000,1.000000,1.000000,0.000000,0.000000

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "HK57GHT"
TEST_RESULT=$?

docker rm -f $CONTAINER_NAME
if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi

echo "TEST 3 - Assert two numbers found after prewarp applied to cropped regions"
IMAGE_NAME=multiple_rotated.jpg
docker run --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME http://127.0.0.1/ --verbose \
      --interval 1 \
      --preprocess 0,0,435,299=planar,429.000000,300.000000,-0.000000,0.000000,0.670000,1.000000,1.000000,0.000000,0.000000 \
      --preprocess 435,0,705,299=planar,272.000000,300.000000,-0.000000,0.000000,-0.650000,1.000000,1.000000,0.000000,0.000000

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "WR62XDF" && find_in_docker_log $CONTAINER_NAME $TIMEOUT "HK57GHT"
TEST_RESULT=$?

docker rm -f $CONTAINER_NAME
if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi
