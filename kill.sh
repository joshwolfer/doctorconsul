#!/bin/bash

# Shell colors for echo outputs
RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m'

echo ""

help () {
    echo -e "Syntax: ./kill.sh [OPTIONS]"
    echo "Default: Kills only the k3d clusters and keeps the k3d registry intact."
    echo ""
    echo "Options:"
    echo "  -docker      Deletes the entire docker environment (Nuke from orbit)."
    echo "  -eks         Nukes consul-k8s and apps in EKS (EKSOnly)"
    echo "  -gke         Nukes consul-k8s and apps in GKE."
    echo ""
    exit 0
}

export ARG_HELP=false
export ARG_DOCKER=false
export ARG_EKS=false
export ARG_GKE=false

if [ $# -eq 0 ]; then
  echo ""
else
  for arg in "$@"; do
    case $arg in
      -docker)
        ARG_DOCKER=true
        ;;
      -eks)
        ARG_EKS=true
        ;;
      -gke)
        ARG_GKE=true
        ;;
      -help)
        ARG_HELP=true
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

if $ARG_DOCKER; then
  if [[ $(docker ps -aq) ]];
    then
      echo -e "${GRN}------------------------------------------"
      echo -e "Nuking all the things... except images of course :D"
      echo -e "------------------------------------------"
      echo -e "${NC}"
      docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker stop; docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs docker rm; docker volume ls | grep -v DRIVER | awk '{print $2}' | xargs docker volume rm; docker network prune -f
    else
      echo -e "${GRN}No containers to nuke.${NC}"
      echo ""
  fi
  exit 0
fi

if $ARG_EKS; then
  echo -e "${GRN}------------------------------------------"
  echo -e "          Executing EKS only Nuke"
  echo -e "------------------------------------------${NC}"
  echo -e ""
  echo -e "Executing:${YELL} ./kube-config.sh -nuke-eks${NC}"
  ./kube-config.sh -nuke-eks
  exit 0
fi

if $ARG_GKE; then
  echo -e "${GRN}------------------------------------------"
  echo -e "          Executing GKE only Nuke"
  echo -e "------------------------------------------${NC}"
  echo -e ""
  echo -e "Executing:${YELL} ./kube-config.sh -nuke-gke${NC}"
  ./kube-config.sh -nuke-gke
  exit 0
fi

# Default behavior
echo -e "${GRN}Nuking k3d clusters ONLY ${NC}"
echo ""
k3d cluster delete dc3
k3d cluster delete dc3-p1
k3d cluster delete dc4
k3d cluster delete dc4-p1
echo ""
exit 0

