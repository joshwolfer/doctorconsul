#!/bin/bash

source ./scripts/functions.sh
# # ^^^ Variables and shared functions

help () {
    echo -e "Syntax: ./start.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  [DEFAULT]   Launch all agents and services with ACL tokens (least privileges)."
    echo "  -root       Launch all agents and services with root tokens"
    echo "  -custom     Launch all agents and services with a custom token config (docker-configs/docker_vars/acl-custom.env)"
    echo ""
    exit 0
}

export ARG_HELP=false
export ARG_ROOT=false
export ARG_CUSTOM=false

if [ $# -gt 0 ]; then
  for arg in "$@"; do
    case $arg in
      -help)
        ARG_HELP=true
        ;;
      -root)
        ARG_ROOT=true
        ;;
      -custom)
        ARG_CUSTOM=true
        ;;
      *)
        echo -e "${RED}Invalid Argument... ${NC}"
        echo ""
        help
        exit 1
        ;;
    esac
  done
fi

if $ARG_HELP; then
  help
fi

clear

# This prevents subsequent commands from causing problems, such as file removal. Make sure we're in the repo clone root.
# Solves problems down the line.
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "doctorconsul" ]; then
    echo -e "${RED}Error: The script must be run from the 'doctorconsul' directory.${NC}"
    exit 1
fi

# Because WSL is pissing me off and the UI metrics grab from Prometheus breaks if the clock is out of sync.
wslClockSync

# Start docker service if it's not running:

export OS_NAME=$(uname)
dockerStart             # Start docker if it's not running
dockerContainersNuke    # Nukes existing Docker containers. Doctor Consul assumes it's the only thing in the docker ecosystem. Probably should warn about this...

rm ./tokens/*.token

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " Building Doctor Consul (VM-style environment) in Docker "
echo -e "------------------------------------------"
echo -e "${NC}"

# Example of M1 Mac ARM64 uname. Might have to do a OS_NAME_FULL that differentiates between M1 vs intel macs if that's an issue.
# $ uname -a
# Darwin jessingrassellino-X96K5442NH 22.6.0 Darwin Kernel Version 22.6.0: Wed Jul  5 22:22:05 PDT 2023; root:xnu-8796.141.3~6/RELEASE_ARM64_T6000 arm64

if [ "$OS_NAME" = "Darwin" ]; then
    echo -e "${YELL}MacOS Detected: Using ARM64 Images ${NC}"
fi

if $ARG_ROOT; then
  if [ "$OS_NAME" = "Linux" ]; then
    echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-root.env up ${NC}"
    echo "=========================================="
    cat ./docker-configs/docker_vars/acl-root.env
    echo ""
    echo "=========================================="
    docker-compose --env-file ./docker-configs/docker_vars/acl-root.env up
    echo ""
    exit 0
  elif [ "$OS_NAME" = "Darwin" ]; then
    echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/mac_arm64-acl-root.env up ${NC}"
    echo "=========================================="
    cat ./docker-configs/docker_vars/mac_arm64-acl-root.env
    echo ""
    echo "=========================================="
    docker-compose --env-file ./docker-configs/docker_vars/mac_arm64-acl-root.env up
    echo ""
    exit 0
  fi
fi

if $ARG_CUSTOM; then
  if [ "$OS_NAME" = "Linux" ]; then
    echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-custom.env up ${NC}"
    echo "=========================================="
    cat ./docker-configs/docker_vars/acl-custom.env
    echo ""
    echo "=========================================="
    docker-compose --env-file ./docker-configs/docker_vars/acl-custom.env up
    echo ""
    exit 0
  elif [ "$OS_NAME" = "Darwin" ]; then
    echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/mac_arm64-acl-custom.env up ${NC}"
    echo "=========================================="
    cat ./docker-configs/docker_vars/mac_arm64-acl-custom.env
    echo ""
    echo "=========================================="
    docker-compose --env-file ./docker-configs/docker_vars/mac_arm64-acl-custom.env up
    echo ""
    exit 0
  fi
fi

# Default behavior, launch in "secure" mode:

if [ "$OS_NAME" = "Linux" ]; then
  echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-secure.env up ${NC}"
  echo "=========================================="
  cat ./docker-configs/docker_vars/acl-secure.env
  echo ""
  echo "=========================================="
  docker-compose --env-file ./docker-configs/docker_vars/acl-secure.env up
  echo ""
elif [ "$OS_NAME" = "Darwin" ]; then
  echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/mac_arm64-acl-secure.env up ${NC}"
  echo "=========================================="
  cat ./docker-configs/docker_vars/mac_arm64-acl-secure.env
  echo ""
  echo "=========================================="
  docker-compose --env-file docker-configs/docker_vars/mac_arm64-acl-secure.env up
  echo ""
fi

