#!/bin/bash

# Shell colors for echo outputs
RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m' # No Color

if [[ "$*" == *"help"* ]]
  then
    echo -e "Syntax: ./start.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  [DEFAULT]   Launch all agents and services with ACL tokens (least privileges)."
    echo "  -root       Launch all agents and services with root tokens"
    echo "  -custom     Launch all agents and services with a custom token config (docker_vars/acl-custom.env)"
    echo ""
    exit 0
fi

clear

echo -e "${GRN}syncing the WSL clock to hardware...${NC}"
# Because WSL is pissing me off and the UI metrics grab from Prometheus breaks if the clock is out of sync.
sudo hwclock -s

echo -e "${GRN} Checking that Docker is running - If not starting it. ${NC}"
pgrep dockerd || sudo service docker start
echo ""

if [[ $(docker ps -aq) ]]; then
    echo -e "${GRN}------------------------------------------"
    echo -e "        Nuking all the things..."
    echo -e "------------------------------------------"
    echo -e "${NC}"
    docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker stop; docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker rm; docker volume ls | grep -v DRIVER | awk '{print $2}' | xargs docker volume rm; docker network prune -f
else
    echo ""
    echo -e "${GRN}No containers to nuke.${NC}"
    echo ""
fi

rm ./tokens/*.token

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "        Rebuilding Doctor Consul"
echo -e "------------------------------------------"
echo -e "${NC}"


if [[ "$*" == *"-root"* ]]
  then
    echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-root.env up ${NC}"
    echo "=========================================="
    cat ./docker_vars/acl-root.env
    echo ""
    echo "=========================================="
    docker-compose --env-file docker_vars/acl-root.env up 
    # docker compose --env-file docker_vars/acl-root.env convert | vsc yaml
    echo ""
    exit 0
fi

if [[ "$*" == *"-custom"* ]]
  then
    echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-custom.env up ${NC}"
    echo "=========================================="
    cat ./docker_vars/acl-custom.env
    echo ""
    echo "=========================================="
    docker-compose --env-file docker_vars/acl-custom.env up 
    # docker compose --env-file docker_vars/acl-custom.env convert | vsc yaml
    echo ""
    exit 0
fi

    echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-secure.env up ${NC}"
    echo "=========================================="
    cat ./docker_vars/acl-secure.env
    echo ""
    echo "=========================================="
    docker-compose --env-file docker_vars/acl-secure.env up 
    # docker compose --env-file docker_vars/acl-secure.env convert | vsc yaml
    echo ""

# Validated the string substitution
# docker compose --env-file ./docker_vars/acl-root.env convert | vsc yaml
