#!/bin/bash

function find_in_docker_log {

    #https://spin.atomicobject.com/2016/12/08/monitoring-stdout-with-a-timeout/

    CONTAINER_NAME=$1
    TIMEOUT=$2
    SUBSTRING=$3
    COMMAND="docker logs -f $CONTAINER_NAME"
    expect -c "log_user 0; set timeout $TIMEOUT; spawn $COMMAND; expect \"$SUBSTRING\" { exit 0 } timeout { exit 1 }"
}

DOCKER_IMAGE_NAME=flyingtophat/alpr
CONTAINER_NAME=alpr_test
TIMEOUT=10

# Test 1
IMAGE_NAME=single_horizontal.jpg
docker run --rm --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME --interval 1

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "WR62XDF"
TEST_RESULT=$?
docker kill $CONTAINER_NAME

if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi


# Test 2
IMAGE_NAME=multiple_rotated.jpg
docker run --rm --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME --interval 1 \
    --preprocess planar,429.000000,300.000000,-0.000000,0.000000,0.670000,1.000000,1.000000,0.000000,0.000000

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "HK57GHT"
TEST_RESULT=$?
docker kill $CONTAINER_NAME

if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi


# Test 3
IMAGE_NAME=multiple_rotated.jpg
docker run --rm --name $CONTAINER_NAME -d $DOCKER_IMAGE_NAME http://127.0.0.1/$IMAGE_NAME --interval 1 \
      --preprocess 0,0,435,299=planar,429.000000,300.000000,-0.000000,0.000000,0.670000,1.000000,1.000000,0.000000,0.000000 \
      --preprocess 435,0,705,299=planar,272.000000,300.000000,-0.000000,0.000000,-0.650000,1.000000,1.000000,0.000000,0.000000

docker exec -d $CONTAINER_NAME python -m SimpleHTTPServer 80
docker cp ./test_files/$IMAGE_NAME $CONTAINER_NAME:/opt/docker-alpr/

find_in_docker_log $CONTAINER_NAME $TIMEOUT "WR62XDF" && find_in_docker_log $CONTAINER_NAME $TIMEOUT "HK57GHT"
TEST_RESULT=$?
docker kill $CONTAINER_NAME

if [ $TEST_RESULT == 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
    exit 1
fi
