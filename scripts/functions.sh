#!/bin/bash

export OS_NAME=$(uname)      # Use this in various parts of the script to make Mac vs Linux decisions. "Darwin" vs "Linux"

export CONSUL_HTTP_TOKEN=root
export CONSUL_HTTP_SSL_VERIFY=false
export CONSUL_HTTP_ADDR="http://127.0.0.1:8500"

export RED='\033[1;31m'
export BLUE='\033[1;34m'
export DGRN='\033[0;32m'
export GRN='\033[1;32m'
export YELL='\033[0;33m'
export NC='\033[0m'

export DC1="http://127.0.0.1:8500"
export DC2="http://127.0.0.1:8501"
export DC3="https://127.0.0.1:8502"
export DC4="https://127.0.0.1:8503"
export DC5=""
export DC6=""

export KDC3="k3d-dc3"
export KDC3_P1="k3d-dc3-p1"
export KDC4="k3d-dc4"
export KDC4_P1="k3d-dc4-p1"

export FAKESERVICE_VER="v0.26.0"

export HELM_CHART_VER=""
# HELM_CHART_VER="--version 1.2.0-rc1"                # pinned consul-k8s chart version


export GCP_PROJECT_ID=hc-1de95f2aa38e498ab96760d6cba
export GCP_REGION=us-east1
# Get the project from the GCP UI upper right hamburger > project settings



# ==============================================================================================================================
#                                                        General Functions
# ==============================================================================================================================

command_check() {
  COMMAND=$1

  if command -v $COMMAND &> /dev/null; then
      echo -e "${GRN}Present:${NC} ${YELL}$COMMAND${NC} ($(command -v $COMMAND))."
  else
      echo ""
      echo -e "${RED}$COMMAND is required by Doctor Consul and could not be found. ${NC}"
      echo -e "Please make sure it is installed and available in your PATH."
      echo ""
      exit 1
  fi
}

file_check() {
  FILE=$1

  if [ -f "$FILE" ]; then
      echo -e "${GRN}Present:${NC} ${YELL}$FILE${NC} (Path: $(realpath $FILE))."
  elif [ "$FILE" == "./license" ]; then
      echo ""
      echo -e "${RED}Not Found:${NC} $FILE."
      echo ""
      echo -e "${RED}The Consul Enterprise license must be stored in $FILE. ${NC}"
      echo -e "Please add the license file to run Doctor Consul."
      echo ""
      exit 1
  else
      echo ""
      echo -e "${RED}$FILE is required and could not be found. ${NC}"
      echo -e "Please make sure the file exists at the specified location."
      echo ""
      exit 1
  fi
}

consul_binary_check() {
  # Check if 'consul' command is available
  if ! command -v consul &> /dev/null
  then
      echo -e "${RED}Consul command could not be found. ${NC}"
      echo -e "Please make sure it is installed and available in your PATH."
      printf "${RED}"'Make sure Consul is on the latest enterprise version!!! '"${NC}\n"
      exit 1
  fi

  # Print the location of 'consul'
  echo -e "${GRN}Present:${NC} ${YELL}$(consul version | grep Consul)${NC} ($(command -v consul))."

  # Run 'consul version' and print only the lines that contain 'Consul'
  printf "${RED}"'Make sure Consul is on the latest enterprise version!!! '"${NC}\n"
}

doctorconsul_dependancies_check() {
  command_check jq
  command_check sed
  command_check helm
  command_check kubectl
  command_check consul-k8s
  consul_binary_check
  file_check ./license
}

CleanupTempStuff () {    # Delete temporary files and kill lingering processes

  echo ""
  echo -e "Nuking the Env Variables...${NC}"
  for var in $(env | grep -Eo '^DC[34][^=]*')
    do
        unset $var
    done

  if [[ $PWD == *"doctorconsul"* ]]; then
    echo -e "Nuking the tokens...${NC}"

    rm -f ./tokens/*
  else
      echo -e "${RED}The kill script should only be executed from within the Doctor Consul Directory.${NC}"
  fi

  echo -e "Nuking kubectl local port forwards...${NC}"
  pkill kubectl
  echo ""
}

fakeservice_from_internet() {  # Pull fake service from the interwebz instead of local k3d registry (which doesn't exist when using EKS)

  # local OS_NAME=$(uname)   # Putting this at the top of the script so it's reusable accross all scripts and functions.

  if [[ "$OS_NAME" == "Linux" ]]; then
    find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
    find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
  elif [[ "$OS_NAME" == "Darwin" ]]; then
    echo "Skipping image swap... MacOS!"
  else
    echo "Operating system not recognized."
  fi
}

fakeservice_from_k3d() {  # Puts the files back to a local k3d registry if they were previously changed (same as checked into the repo)

  local OS_NAME=$(uname)

  if [[ "$OS_NAME" == "Linux" ]]; then
    find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
    find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
  elif [[ "$OS_NAME" == "Darwin" ]]; then
    echo "Skipping image swap... MacOS!"
  else
    echo "Operating system not recognized."
  fi
}

wait_for_consul_connect_inject_service() {
    local context="$1"
    local deployment_name="$2"
    local label="$3"

    echo -e "${RED}Waiting for ${label} connect-inject service to be ready...${NC}"
    until kubectl get deployment "${deployment_name}" -n consul --context "${context}" -ojson | jq -r .status.availableReplicas | grep 1 > /dev/null; do
        echo -e "${RED}Waiting for ${label} connect-inject service to be ready...${NC}"
        sleep 3
    done
    echo -e "${YELL}${label} connect-inject service is READY! ${NC}"
    echo -e ""

    # Example:
    # wait_for_consul_connect_inject_service $KDC3 "consul-connect-injector" "DC3 (default)"
}

wait_for_kube_service() {    # Example: wait_for_kube_service vault-ui vault $CONTEXT 10 VAULT_HOST

  local svc_name=$1          # Kube service name
  local namespace=$2         # Kube namespace
  local context=$3           # Kube context
  local max_retries=$4
  local counter=0
  local hostname_var_name=$5 # Variable name to reference in this script
  local jq_query=""

  # Debugging prints
  # echo "Function called with parameters:"
  # echo "Service name: $svc_name"
  # echo "Namespace: $namespace"
  # echo "Context: $context"
  # echo "Max retries: $max_retries"
  # echo "Host variable name: $hostname_var_name"

  # Determine which jq query to use based on $ARG_EKSONLY
  if $ARG_EKSONLY; then
    jq_query='.status.loadBalancer.ingress[0].hostname'     # AWS uses hostnames
  else
    jq_query='.status.loadBalancer.ingress[0].ip'           # K3d uses IPs
  fi

  echo "Using jq query: $jq_query"  # Debug print

  while [ $counter -lt $max_retries ]; do
    local lb_address=$(kubectl get svc $svc_name -n$namespace --context $context -o json | jq -r "$jq_query")

    # echo "Current lb_address value: $lb_address"   # Debug print

    if [ ! -z "$lb_address" ] && [ "$lb_address" != "null" ]; then
      eval "$hostname_var_name=$lb_address"
      break
    fi

    counter=$((counter+1))
    if [ $counter -eq $max_retries ]; then
      echo "Giving up on $svc_name after $max_retries attempts."
      break
    fi

    echo "Waiting for $svc_name load balancer to get an ingress... Attempt $counter/$max_retries."
    sleep 3
  done
}

k3dPeeringToVM() {
  # Peers the local k3d clusters to the doctor consul docker compose clusters DC1 / DC2 (they must be running, obviously)

  # ------------------------------------------
  # Peer DC3/default -> DC1/default
  # ------------------------------------------

  echo -e ""
  echo -e "${GRN}DC3/default -> DC1/default${NC}"

  consul peering generate-token -name dc3-default -http-addr="$DC1" > tokens/peering-dc1_default-dc3-default.token

  kubectl create secret generic peering-token-dc1-default-dc3-default --namespace consul --from-literal=data=$(cat tokens/peering-dc1_default-dc3-default.token)
  kubectl label secret peering-token-dc1-default-dc3-default -n consul "consul.hashicorp.com/peering-token=true"
  kubectl apply --namespace consul -f ./kube/configs/peering/peering_dc3-default_dc1-default.yaml

  # ------------------------------------------
  # Peer DC3/default -> DC1/Unicorn
  # ------------------------------------------

  echo -e ""
  echo -e "${GRN}DC3/default -> DC1/Unicorn${NC}"

  consul peering generate-token -name dc3-default -partition="unicorn" -http-addr="$DC1" > tokens/peering-dc3-default_dc1-unicorn.token

  kubectl create secret generic peering-token-dc3-default-dc1-unicorn --namespace consul --from-literal=data=$(cat tokens/peering-dc3-default_dc1-unicorn.token)
  kubectl label secret peering-token-dc3-default-dc1-unicorn -n consul "consul.hashicorp.com/peering-token=true"
  kubectl apply --namespace consul -f ./kube/configs/peering/peering_dc3-default_dc1-unicorn.yaml

  # ------------------------------------------
  # Peer DC3/default -> DC2/Unicorn
  # ------------------------------------------

  echo -e ""
  echo -e "${GRN}DC3/default -> DC2/Unicorn${NC}"

  consul peering generate-token -name dc3-default -partition="unicorn" -http-addr="$DC2" > tokens/peering-dc3-default_dc2-unicorn.token

  kubectl create secret generic peering-token-dc3-default-dc2-unicorn --namespace consul --from-literal=data=$(cat tokens/peering-dc3-default_dc2-unicorn.token)
  kubectl label secret peering-token-dc3-default-dc2-unicorn -n consul "consul.hashicorp.com/peering-token=true"
  kubectl apply --namespace consul -f ./kube/configs/peering/peering_dc3-default_dc2-unicorn.yaml
}

UpgradeConsulBinary() {
  (
    # If no argument is provided, prompt the user for input
    if [ -z "$1" ]; then
        while true; do
            read -p "Please specify a Consul version (or enter 'latest' or 'latest+ent'): " input_version
            if [[ "$input_version" =~ ^(latest|latest\+ent|[0-9]+\.[0-9]+\.[0-9]+(\+ent)?)$ ]]; then
                CONSUL_VER=${input_version}
                break
            else
                echo "Invalid format. Please enter a valid Consul version (or 'latest' or 'latest+ent')."
            fi
        done
    else
        if [[ ! "$1" =~ ^(latest|latest\+ent|[0-9]+\.[0-9]+\.[0-9]+(\+ent)?)$ ]]; then
            echo "Invalid argument format."
            exit 1
        fi
        CONSUL_VER="$1"
    fi

    if [ "$CONSUL_VER" == "latest" ]; then
        CONSUL_VER="$(curl -s "https://api.github.com/repos/hashicorp/consul/releases/latest" | jq -r .tag_name | sed 's/^v//')"
    elif [ "$CONSUL_VER" == "latest+ent" ]; then
        CONSUL_VER="$(curl -s "https://api.github.com/repos/hashicorp/consul/releases/latest" | jq -r .tag_name | sed 's/^v//')+ent"
    fi

    curl -s "https://api.github.com/repos/hashicorp/consul/releases/latest" | jq -r .tag_name | sed 's/^v//'

    DIR=$HOME/consul_temp
    BIN_DIR=/usr/local/bin

    echo -e "${YELL}local binary directory is:${NC}$BIN_DIR"
    echo -e "${YELL}Temp Directory is:${NC}"$DIR
    echo ""

    if [ ! -d "$DIR" ]; then
    mkdir "$DIR"
    fi

    cd "$DIR" || exit

    echo -e "${GRN}Downloading and unzipping Consul: ${NC}"
    wget -q https://releases.hashicorp.com/consul/$CONSUL_VER/consul_${CONSUL_VER}_linux_amd64.zip
    unzip consul_${CONSUL_VER}_linux_amd64.zip

    echo ""
    echo -e "${GRN}Moving Consul ($CONSUL_VER) to $BIN_DIR${NC}"
    mv consul consul-$CONSUL_VER
    sudo mv consul-$CONSUL_VER $BIN_DIR

    # if [ -e "$BIN_DIR/consul" ] || [ -L "$BIN_DIR/consul" ]; then    # Nuke symlink or existing consul binary.
    #     sudo rm "$BIN_DIR/consul"
    # fi

    sudo ln -sf $BIN_DIR/consul_${CONSUL_VER} $BIN_DIR/consul    # New symlink

    echo ""
    echo -e "${RED}Deleting Temp directory:${NC} $DIR"
    rm -rf $DIR

    echo ""

  )
}

wslClockSync() {

  WSL=$(uname -a)

  if [[ $WSL == *"WSL"* ]]; then
    echo -e "${GRN}syncing the WSL clock to hardware...${NC}"
    sudo hwclock -s
  fi

}

dockerStart() {   # Start docker if it's not running
  if [ "$OS_NAME" == "Linux" ]; then
    echo ""
    echo -e "${GRN}Checking that Docker is running - If not starting it. ${NC}"
    pgrep dockerd || sudo service docker start
    echo ""

    sleep 2
  else
      # Eventually put in mac syntax to start docker, its not the same as linux
      echo ""
  fi
}

dockerContainersNuke() {   # Nukes existing Docker containers.
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
}

waitForConsulLeader() {    # Wait for Leaders to be elected (CONSUL_API_ADDR, Name of DC)
  local CONSUL_ADDRESS=$1
  local DC_NAME=$2

  until curl -s -k ${CONSUL_ADDRESS}/v1/status/leader | grep 8300; do
    echo -e "${RED}Waiting for ${DC_NAME} Consul to start${NC}"
    sleep 1
  done
}

# ==============================================================================================================================
#                                                AWS (EKSOnly) Functions
# ==============================================================================================================================

update_aws_context() {
    echo ""
    echo -e "${GRN}Setting Contexts from EKSonly (https://github.com/ramramhariram/EKSonly):${NC}"
    echo ""
    echo -e "${YELL}EKSONLY_TF_STATE_FILE:${NC} Terraform EKSOnly state file is currently: $EKSONLY_TF_STATE_FILE"
    echo -e "${YELL}AWS_REGION:${NC} $AWS_REGION"
    echo ""
    aws eks update-kubeconfig --region $AWS_REGION --name nEKS0 --alias $KDC3 || { echo -e "${RED}Did you specify the correct AWS region (AWS_REGION) and tfstate file (EKSONLY_TF_STATE_FILE)? ${NC}"; echo ""; echo -e "${RED}Is the date/time correct on your computer?${NC}"; echo ""; exit 1; }
    aws eks update-kubeconfig --region $AWS_REGION --name nEKS1 --alias $KDC3_P1
    aws eks update-kubeconfig --region $AWS_REGION --name nEKS2 --alias $KDC4
    aws eks update-kubeconfig --region $AWS_REGION --name nEKS3 --alias $KDC4_P1
    echo ""
}

nuke_consul_k8s() {
  set +e

  echo -e "${RED}"
  echo -e "=========================================="
  echo -e " Stage 1: Consul-k8s uninstalls"
  echo -e "==========================================${NC}"

  echo -e "${GRN}Deleting Consul Helm installs in each Cluster:${NC}"

  echo -e "${YELL}DC3:${NC} $(consul-k8s uninstall -auto-approve -context $KDC3)" &
  echo -e "${YELL}DC3_P1:${NC} $(consul-k8s uninstall -auto-approve -context $KDC3_P1)" &
  echo -e "${YELL}DC4:${NC} $(consul-k8s uninstall -auto-approve -context $KDC4)" &
  echo -e "${YELL}DC4_P1:${NC} $(consul-k8s uninstall -auto-approve -context $KDC4_P1)" &

  wait    # We might need to wait for these to finish before we can proceed to nuking other things.

  echo ""

  echo -e "${GRN}Deleting additional DC3 Loadbalancer services:${NC}"
  kubectl delete --namespace consul --context $KDC3 -f ./kube/prometheus/dc3-prometheus-service.yaml
  kubectl delete svc unicorn-frontend -n unicorn --context $KDC3 &
  kubectl delete svc consul-api-gateway -n consul --context $KDC3 &

  echo -e "${GRN}Deleting additional DC3 (Cernunnos) Loadbalancer services:${NC}"
  kubectl delete svc leroy-jenkins -n paris --context $KDC3_P1 &
  kubectl delete svc pretty-please -n paris --context $KDC3_P1 &

  echo -e "${GRN}Deleting additional DC4 Loadbalancer services:${NC}"
  kubectl delete svc sheol-app -n sheol --context $KDC4 &
  kubectl delete svc sheol-app1 -n sheol-app1 --context $KDC4 &
  kubectl delete svc sheol-app2 -n sheol-app2 --context $KDC4 &

  wait

  echo -e "${RED}"
  echo -e "=========================================="
  echo -e " Stage 3: Nuke leftover CRDs"
  echo -e "==========================================${NC}"


  # If you need to nuke all the CRDs to nuke namespaces, this can be used. Don't typically need to do this just to "tf destroy" though.
  # This is really on for rebuilding Doctor Consul useing the same eksonly clusters.
  export CONTEXTS=("$KDC3" "$KDC3_P1" "$KDC4" "$KDC4_P1")

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl get crd -n consul --context $CONTEXT -o jsonpath='{.items[*].metadata.name}' | tr -s ' ' '\n' | grep "consul.hashicorp.com" | while read -r CRD
    do
      kubectl patch crd/$CRD -n consul --context $CONTEXT -p '{"metadata":{"finalizers":[]}}' --type=merge
      kubectl delete crd/$CRD --context $CONTEXT
    done
  done

  wait

  echo -e "${RED}"
  echo -e "=========================================="
  echo -e " Stage 4: Nuke namespaces  "
  echo -e "==========================================${NC}"

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace consul --context $CONTEXT
  done



  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace vault --context $CONTEXT
  done



  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace unicorn --context $CONTEXT
  done



  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace externalz --context $CONTEXT
  done


  kubectl delete namespace sheol --context $KDC4
  kubectl delete namespace sheol-app1 --context $KDC4
  kubectl delete namespace sheol-app2 --context $KDC4
  kubectl delete namespace paris --context $KDC3_P1

  wait

  echo -e "${RED}"
  echo -e "=========================================="
  echo -e " Stage 5: Clean Local Temp stuff  "
  echo -e "==========================================${NC}"

  CleanupTempStuff

  wait

}

# ==============================================================================================================================
#                                                     GKE Functions
# ==============================================================================================================================

# Function to create GKE cluster

create_gke_cluster() {
    local CLUSTER_NAME="$1"


    # This creates autopilot clusters, which are evidently unsupport in Consul as of right now (Sept 2023)

    # (gcloud container clusters create-auto "$CLUSTER_NAME" \
    #   --project $GCP_PROJECT_ID \
    #   --region $GCP_REGION --release-channel "regular" \
    #   --network "projects/$GCP_PROJECT_ID/global/networks/default" \
    #   --subnetwork "projects/$GCP_PROJECT_ID/regions/$GCP_REGION/subnetworks/default" \
    #   --cluster-ipv4-cidr "/17" > /dev/null 2>&1 && echo "Cluster $CLUSTER_NAME creation successful!" || echo "Cluster $CLUSTER_NAME creation failed!") &


    # This creates "standard clusters"

    (gcloud container clusters create "$CLUSTER_NAME" \
      --project $GCP_PROJECT_ID \
      --zone us-east1-b --node-locations us-east1-b,us-east1-c \
      --release-channel "regular" \
      --network "projects/$GCP_PROJECT_ID/global/networks/default" \
      --subnetwork "projects/$GCP_PROJECT_ID/regions/$GCP_REGION/subnetworks/default" \
      --cluster-ipv4-cidr "/17" > /dev/null 2>&1 && echo "Cluster $CLUSTER_NAME creation successful!" || echo "Cluster $CLUSTER_NAME creation failed!") &

}

# Change gke contexts to match doctor consul friendly ones.

update_gke_context() {
    local CLUSTER_NAME="$1"

    echo ""
    echo -e "${GRN}$CLUSTER_NAME:${NC}"

    # Update kube config from GKE
    gcloud container clusters get-credentials $CLUSTER_NAME --region $GCP_REGION --project $GCP_PROJECT_ID

    # Delete the context
    kubectl config delete-context "$CLUSTER_NAME"

    # Rename the context
    kubectl config rename-context gke_${GCP_PROJECT_ID}_${GCP_REGION}_$CLUSTER_NAME $CLUSTER_NAME
}

# ==============================================================================================================================
#                                                             FIN
# ==============================================================================================================================

# echo ""
# echo -e "${GRN}Functions file is done sourced. ${NC}"
# echo ""
