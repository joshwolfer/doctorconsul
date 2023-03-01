#!/bin/bash

if [[ $(docker ps -aq) ]]; then
    echo "------------------------------------------"
    echo "        Nuking all the things..."
    echo "------------------------------------------"
    echo ""
    docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker stop; docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker rm; docker volume ls | grep -v DRIVER | awk '{print $2}' | xargs docker volume rm; docker network prune -f
else
    echo "No containers to nuke."
    echo ""
fi

rm ./tokens/*.token

echo ""
echo "------------------------------------------"
echo "        Rebuilding Doctor Consul"
echo "------------------------------------------"
echo ""

docker-compose up
