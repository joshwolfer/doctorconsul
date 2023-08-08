#!/bin/bash

set -e

export CONSUL_HTTP_TOKEN=root
export CONSUL_HTTP_SSL_VERIFY=false

# HOME=$(pwd)
# For some stupid reason k3d won't allow "./" in the path for config files so we have to do this non-sense for the Calico config to load...

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

export FAKESERVICE_VER="v0.25.0"

export HELM_CHART_VER=""
# HELM_CHART_VER="--version 1.2.0-rc1"                # pinned consul-k8s chart version

export EKSONLY_TF_STATE_FILE="/home/mourne/git/EKSonly/terraform.tfstate"
# Set this to the path of the EKSOnly repo so the outputs can be read! This MUST be set correctly!!!

help () {
    echo -e "Syntax: ./kube-config.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k3d-full           Integrate with full docker compose environment. Without this, only launch Consul in k3d"
    echo "  -k8s-only           Only Install raw K3d clusters without Consul. Useful when you want to play with k8s alone"
    echo "  -update             Update K3d to the latest version"
    echo "  -eksonly            Sets 4 Kube Contexts to the appropriate names from EKSonly (https://github.com/ramramhariram/EKSonly)"
    echo "  -eksonly-context    Refreshes the EKSOnly Kube Contexts"
    echo "  -nuke-eksonly       Destroy the EKSOnly resources so it's safe to tf destroy"
    echo "  -no-apps            Install Consul into clusters with additional NO services"
    echo "  -debug              Run Helm installation with --debug"
    echo ""
    exit 0
}

# ------------------------------------------
#    Parse Arguments into variables
# ------------------------------------------

export ARG_K3D_FULL=false
export ARG_K8S_ONLY=false
export ARG_UPDATE=false
export ARG_EKSONLY=false
export ARG_EKSONLY_CONTEXT=false
export ARG_NUKE_EKSONLY=false
export ARG_NO_APPS=false
export ARG_DEBUG=false
export ARG_HELP=false

if [ $# -eq 0 ]; then
  echo ""
else
  for arg in "$@"; do
    case $arg in
      -k3d-full)
        ARG_K3D_FULL=true
        ;;
      -k8s-only)
        ARG_K8S_ONLY=true
        ;;
      -update)
        ARG_UPDATE=true
        ;;
      -eksonly)
        ARG_EKSONLY=true
        ;;
      -eksonly-context)
        ARG_EKSONLY_CONTEXT=true
        ;;
      -nuke-eksonly)
        ARG_NUKE_EKSONLY=true
        ;;
      -no-apps)
        ARG_NO_APPS=true
        ;;
      -debug)
        ARG_DEBUG=true
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

if [ "$ARG_EKSONLY" = "true" ] || [ "$ARG_EKSONLY_CONTEXT" = "true" ]; then
  echo -e "${GRN}Setting Contexts from EKSonly (https://github.com/ramramhariram/EKSonly):${NC}"
  echo ""
  aws eks update-kubeconfig --region us-east-1 --name nEKS0 --alias k3d-dc3
  aws eks update-kubeconfig --region us-east-1 --name nEKS1 --alias k3d-dc3-p1
  aws eks update-kubeconfig --region us-east-1 --name nEKS2 --alias k3d-dc4
  aws eks update-kubeconfig --region us-east-1 --name nEKS3 --alias k3d-dc4-p1
  echo ""
  echo -e "${YELL}Terraform EKSOnly state file is currently:${NC} $EKSONLY_TF_STATE_FILE"
  echo ""
fi

if $ARG_EKSONLY_CONTEXT; then
  echo -e "${GRN}Exiting (-eksonly-context)${NC}"
  echo ""
  exit 0
fi

CleanupTempStuff () {

  echo ""
  echo -e "${RED}Nuking the Env Variables...${NC}"
  for var in $(env | grep -Eo '^DC[34][^=]*')
    do
        unset $var
    done

  if [[ $PWD == *"doctorconsul"* ]]; then
    echo -e "${RED}Nuking the tokens...${NC}"

    rm -f ./tokens/*
  else
      echo -e "${RED}The kill script should only be executed from within the Doctor Consul Directory.${NC}"
  fi

  echo -e "${RED}Nuking kubectl local port forwards...${NC}"
  pkill kubectl
  echo ""
}

if $ARG_NUKE_EKSONLY; then
  set +e
  echo -e "${GRN}Deleting Consul Helm installs in each Cluster:${NC}"

  echo -e "${YELL}DC3:${NC}"
  consul-k8s uninstall -auto-approve -context $KDC3
  # helm delete consul --namespace consul --kube-context $KDC3

  echo -e "${YELL}DC3_P1:${NC}"
  consul-k8s uninstall -auto-approve -context $KDC3_P1
  # helm delete consul --namespace consul --kube-context $KDC3_P1

  echo -e "${YELL}DC4:${NC}"
  consul-k8s uninstall -auto-approve -context $KDC4
  # helm delete consul --namespace consul --kube-context $KDC4

  echo -e "${YELL}DC4_P1:${NC}"
  consul-k8s uninstall -auto-approve -context $KDC4_P1
  # helm delete consul --namespace consul --kube-context $KDC4_P1
  echo ""

  echo -e "${GRN}Deleting additional DC3 Loadbalancer services:${NC}"
  kubectl delete --namespace consul --context $KDC3 -f ./kube/prometheus/dc3-prometheus-service.yaml
  kubectl delete svc unicorn-frontend -n unicorn --context $KDC3
  kubectl delete svc consul-api-gateway -n consul --context $KDC3

  # If you need to nuke all the CRDs to nuke namespaces, this can be used. Don't typically need to do this just to "tf destroy" though.
  # This is really on for rebuilding Doctor Consul useing the same eksonly clusters.
  CONTEXTS=("$KDC3" "$KDC3_P1" "$KDC4" "$KDC4_P1")

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl get crd -n consul --context $CONTEXT -o jsonpath='{.items[*].metadata.name}' | tr -s ' ' '\n' | grep "consul.hashicorp.com" | while read -r CRD
    do
      kubectl patch crd/$CRD -n consul --context $CONTEXT -p '{"metadata":{"finalizers":[]}}' --type=merge
      kubectl delete crd/$CRD --context $CONTEXT
    done
  done

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace consul --context $CONTEXT
  done

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace unicorn --context $CONTEXT
  done

  for CONTEXT in "${CONTEXTS[@]}"; do
    kubectl delete namespace externalz --context $CONTEXT
  done

  CleanupTempStuff

  echo ""
  echo -e "${RED}It's now safe to TF destroy! ${NC}"
  echo ""

  exit 0     # Exit here.
fi

if $ARG_UPDATE; then
  echo ""
  echo -e "${GRN}Updating K3d... ${NC}"
  echo -e "${YELL}Pulling from https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh ${NC}"
  wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  echo ""
  exit 0
fi

if $ARG_K8S_ONLY; then
  echo -e "${RED} Building K3d clusters ONLY (-k8s-only) ${NC}"
fi

if [[ $PWD == *"doctorconsul"* ]]; then rm -f ./logs/*.log; fi
# Delete out the previous logs

# ------------------------------------------
#           Consul binary check
# ------------------------------------------

echo -e "${GRN}Consul Binary Check: ${NC}"
# Check if 'consul' command is available
if ! command -v consul &> /dev/null
then
    echo -e "${RED}Consul command could not be found. ${NC}"
    echo -e "Please make sure it is installed and available in your PATH."
    printf "${RED}"'Make sure Consul is on the latest enterprise version!!! '"${NC}\n"
    exit 1
fi

# Print the location of 'consul'
echo -e "Consul is located at: ${YELL}$(which consul)"

# Run 'consul version' and print only the lines that contain 'Consul'
echo -e "${YELL}$(consul version | grep Consul) ${NC}"
printf "${RED}"'Make sure Consul is on the latest enterprise version!!! '"${NC}\n"

# ------------------------------------------
#           Tokens Directory
# ------------------------------------------

mkdir -p ./tokens/
# Creates the tokens directory (used later, and also in the .gitignore)

# ==========================================
# Checks if we're provisioning using EKSOnly or k3d
# ==========================================

if $ARG_EKSONLY;
  then
    # Matching eksonly skips all the k3d stuff
    echo ""
    echo -e "${RED}Skipping k3d cluster install${NC}"
    echo ""
  else

    ./k3d-config.sh

fi
# Ends the eksonly bypass

# ==============================================================================================================================
# ==============================================================================================================================
#
#                           Consul is actually installed into Kube clusters from HERE on
#
# ==============================================================================================================================
# ==============================================================================================================================

./helm-install.sh
# Execute helm install script.


# ==========================================
#              Prometheus configs
# ==========================================

kubectl config use-context $KDC3

echo -e "${GRN}"
echo -e "=========================================="
echo -e "             Prometheus configs"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}Setup Prometheus service in DC3 ${NC}"
kubectl apply --namespace consul -f ./kube/prometheus/dc3-prometheus-service.yaml --context $KDC3

# ==========================================
#              Consul configs
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "             Consul configs"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}Wait for DC3, DC3-cernunnos, DC4, and DC4-taranis connect-inject services to be ready before starting resource provisioning${NC}"

echo -e "${RED}Waiting for DC3 (default) connect-inject service to be ready...${NC}"
until kubectl get deployment consul-connect-injector -n consul --context $KDC3 -ojson | jq -r .status.availableReplicas | grep 1; do
  echo -e "${RED}Waiting for DC3 (default) connect-inject service to be ready...${NC}"
  sleep 1
done
echo -e "${YELL}DC3 (default) connect-inject service is READY! ${NC}"
echo -e ""

echo -e "${RED}Waiting for DC3 (cernunnos) connect-inject service to be ready...${NC}"
until kubectl get deployment consul-cernunnos-connect-injector -n consul --context $KDC3_P1 -ojson | jq -r .status.availableReplicas | grep 1; do
  echo -e "${RED}Waiting for DC3 (cernunnos) connect-inject service to be ready...${NC}"
  sleep 1
done
echo -e "${YELL}DC3 (cernunnos) connect-inject service is READY! ${NC}"
echo -e ""

echo -e "${RED}Waiting for DC4 (default) connect-inject service to be ready...${NC}"
until kubectl get deployment consul-connect-injector -n consul --context $KDC4 -ojson | jq -r .status.availableReplicas | grep 1; do
  echo -e "${RED}Waiting for DC4 (default) connect-inject service to be ready...${NC}"
  sleep 1
done
echo -e "${YELL}DC4 (default) connect-inject service is READY! ${NC}"
echo -e ""

echo -e "${RED}Waiting for DC4 (taranis) connect-inject service to be ready...${NC}"
until kubectl get deployment consul-taranis-connect-injector -n consul --context $KDC4_P1 -ojson | jq -r .status.availableReplicas | grep 1; do
  echo -e "${RED}Waiting for DC4 (taranis) connect-inject service to be ready...${NC}"
  sleep 1
done
echo -e "${YELL}DC4 (taranis) connect-inject service is READY! ${NC}"

  # ------------------------------------------
  #   Pull in address information from sub processes
  # ------------------------------------------

  # TLDR; Because the helm installation functions are launched as background shells to build in parallel (performance reasons)
  # Environment variables cannot be passed back to this parent script. So the sub shells write these addresses to temp disk and
  # we re-assign the variables here. MAGIC.

    DC3_LB_IP=$(cat ./tokens/dc3_lb_ip.txt)
    DC3_P1_K8S_IP=$(cat ./tokens/dc3_p1_k8s_ip.txt)

    DC4_LB_IP=$(cat ./tokens/dc4_lb_ip.txt)
    DC4_P1_K8S_IP=$(cat ./tokens/dc4_p1_k8s_ip.txt)

    DC3="http://$DC3_LB_IP:8500"
    DC4="http://$DC4_LB_IP:8500"
    echo -e "${GRN}Export ENV Variables ${NC}"
    echo "export DC3=http://$DC3_LB_IP:8500"
    echo "export DC4=http://$DC4_LB_IP:8500"


  # ------------------------------------------
  # Peering over Mesh Gateway
  # ------------------------------------------

echo -e ""
echo -e "${GRN}(DC3): MGW Peering over Gateways${NC}"
kubectl --context $KDC3 apply -f ./kube/configs/peering/mgw-peering.yaml

echo -e ""
echo -e "${GRN}(DC4): MGW Peering over Gateways${NC}"
kubectl --context $KDC4 apply -f ./kube/configs/peering/mgw-peering.yaml

# ==============================================================================================================================
#            Cluster Peering
# ==============================================================================================================================

k3dPeeringToVM () {

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

# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#            Check for -k3d-full
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

if $ARG_K3D_FULL;
  then
    k3dPeeringToVM
  else
    echo ""
    echo -e "${RED} *** VM-based Cluster Peering Bypassed ${NC}"
    echo ""
fi

# ------------------------------------------
# Peer DC4/default -> DC3/default
# ------------------------------------------

echo -e ""
echo -e "${GRN}DC4/default -> DC3/default${NC}"

consul peering generate-token -name dc4-default -http-addr="$DC3" > tokens/peering-dc3_default-dc4-default.token
consul peering establish -name dc3-default -http-addr="$DC4" -peering-token $(cat tokens/peering-dc3_default-dc4-default.token)

## Doing the peering through Consul CLI/API, because it's gonna be a pain to inject MGW addresses into CRD YAML.
## Should probably do that at some point
## It's also a royal pain in the ass to create kube secrets for every peer relationship between Kube.

# ------------------------------------------
# Peer DC4/taranis -> DC3/default
# ------------------------------------------

echo -e ""
echo -e "${GRN}DC4/taranis -> DC3/default${NC}"

consul peering generate-token -name dc4-taranis -http-addr="$DC3" > tokens/peering-dc3_default-dc4-taranis.token
consul peering establish -name dc3-default -partition taranis -http-addr="$DC4" -peering-token $(cat tokens/peering-dc3_default-dc4-taranis.token)

# Delete: consul peering delete -name dc3-default -partition taranis


# ==========================================
#        Applications / Deployments
# ==========================================

if $ARG_NO_APPS;
  then
echo -e "$(cat << EOF
${RED} Consul is installed. Exiting before applications are installed! ${NC}

${GRN}
------------------------------------------
         EKSOnly Outputs (No Apps)
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: http://$DC3_LB_IP:8500
 ${YELL}DC4${NC}: http://$DC4_LB_IP:8500

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Export ENV Variables ${NC}
 export DC3=http://$DC3_LB_IP:8500
 export DC4=http://$DC4_LB_IP:8500

 KDC3=k3d-dc3
 KDC3_P1=k3d-dc3-p1
 KDC4=k3d-dc4
 KDC4_P1=k3d-dc4-p1

${GRN}Port forwards to map UI to traditional Doctor Consul local ports: ${NC}
 kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &
 kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &

${RED}Happy Consul'ing!!! ${NC}

Before running ${YELL}terraform destroy${NC}, first run ${YELL}./kill.sh -eksonly${NC} to prevent AWS from horking. Trust me.

You can now start manually provisioning the applications in the kube-config.sh starting at line: $(grep -n "Install Unicorn Application" ./kube-config.sh | cut -f1 -d: | awk 'NR==2')
EOF
)"
    exit 0
fi

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Unicorn Application"
echo -e "==========================================${NC}"

# ------------------------------------------
#  Modify the service yaml to pull images on EKS vs k3d local
# ------------------------------------------

# The Fakeservice app yaml is all set to use a local k3d registry by default.
# This makes it so the docker image addresses are changed to public dockerhub if installing into EKSonly (AWS).
# And switches them back to k3d local if no argument is provided.

if $ARG_EKSONLY;
  then
    find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
    find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
# Pull fake service from the interwebz instead of local k3d registry (which doesn't exist when using EKS)
  else
    find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
    find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
    # Puts the files back to a local k3d registry if they were previously changed (same as checked into the repo)
fi


# ------------------------------------------
#  Create Namespaces for Unicorn
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "        Create Unicorn Namespaces"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): Create unicorn namespace${NC}"

kubectl create namespace unicorn --context $KDC3

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Create unicorn namespace${NC}"

kubectl create namespace unicorn --context $KDC3_P1

echo -e ""
echo -e "${GRN}DC4 (default): Create unicorn namespace${NC}"

kubectl create namespace unicorn --context $KDC4

echo -e ""
echo -e "${GRN}DC4 (taranis): Create unicorn namespace${NC}"

kubectl create namespace unicorn --context $KDC4_P1

# Ideal order of operations, per Derek:

#    1. Setup your service-defaults or proxy-defaults or whatever is setting the protocol
#    2. Create the SG
#    3. Create the exports
#    4. Create everything else


# ------------------------------------------
#               proxy-defaults
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "             proxy-defaults"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): proxy-defaults ${NC}- MGW mode:${YELL}Local${NC} Proto:${YELL}HTTP ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/defaults/proxy-defaults.yaml
echo -e "${GRN}DC3 (cernunnos): proxy-defaults${NC} - MGW mode:${YELL}Local${NC} Proto:${YELL}HTTP ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/defaults/proxy-defaults.yaml

echo -e "${GRN}DC3 (default): proxy-defaults ${NC}- MGW mode:${YELL}Local${NC} Proto:${YELL}HTTP ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc3/defaults/proxy-defaults.yaml
echo -e "${GRN}DC3 (cernunnos): proxy-defaults${NC} - MGW mode:${YELL}Local${NC} Proto:${YELL}HTTP ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc3/defaults/proxy-defaults.yaml

# ------------------------------------------
#           Exported-services
# ------------------------------------------

# If exports aren't before services are launch, it shits in Consul Dataplane mode.

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "           Exported Services"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): Export services from the ${YELL}default ${GRN}partition ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/exported-services/exported-services-dc3-default.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Export services from the ${YELL}cernunnos ${GRN}partition ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/exported-services/exported-services-dc3-cernunnos.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Export services from the ${YELL}default ${GRN}partition ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/exported-services/exported-services-dc4-default.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Export services from the ${YELL}taranis ${GRN}partition ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/exported-services/exported-services-dc4-taranis.yaml

echo -e ""

# ------------------------------------------
#          Service Sameness Groups
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "       Service Sameness Groups"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): Apply Sameness Group: ssg-unicorn ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/sameness-groups/dc3-default-ssg-unicorn.yaml

echo -e "${GRN}DC3 (cernunnos): Apply Sameness Group: ssg-unicorn ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/sameness-groups/dc3-cernunnos-ssg-unicorn.yaml

echo -e "${GRN}DC4 (default): Apply Sameness Group: ssg-unicorn ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/sameness-groups/dc4-default-ssg-unicorn.yaml

echo -e "${GRN}DC4 (taranis): Apply Sameness Group: ssg-unicorn ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/sameness-groups/dc4-taranis-ssg-unicorn.yaml

# ------------------------------------------
#     Services
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "    Launch Kube Consul Service Configs"
echo -e "------------------------------------------${NC}"

# ----------------
# Unicorn-frontends
# ----------------

echo -e ""
echo -e "${GRN}DC3 (default): Apply Unicorn-frontend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml

# ----------------
# Unicorn-backends
# ----------------

echo -e ""
echo -e "${GRN}DC3 (default): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml


echo -e ""
echo -e "${GRN}DC3 (cernunnos): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/services/unicorn-backend.yaml
# kubectl delete --context $KDC4 -f ./kube/configs/dc4/services/unicorn-backend.yaml


echo -e ""
echo -e "${GRN}DC4 (taranis): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/services/unicorn-taranis-backend.yaml
# kubectl delete --context $KDC4_P1 -f ./kube/configs/dc4/services/unicorn-taranis-backend.yaml


# ----------------
# Transparent Unicorn-backends
# ----------------

echo -e ""
echo -e "${GRN}DC3 (default): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/unicorn-tp_backend.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/services/unicorn-tp_backend.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-tp_backend.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-tp_backend.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/services/unicorn-tp_backend.yaml
# kubectl delete --context $KDC4 -f ./kube/configs/dc4/services/unicorn-tp_backend.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Apply Unicorn-backend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/services/unicorn-taranis-tp_backend.yaml
# kubectl delete --context $KDC4_P1 -f ./kube/configs/dc4/services/unicorn-taranis-tp_backend.yaml

# ------------------------------------------
#                    Mesh Defaults
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "            Mesh Defaults"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): mesh config: ${YELL}Mesh Destinations Only: False ${NC}"      # leave only one of these on
# echo -e "${GRN}DC3 (default): mesh config: ${YELL}Mesh Destinations Only: True ${NC}"
# kubectl apply --context $KDC3 -f ./kube/configs/dc3/defaults/mesh.yaml

# ------------------------------------------
#                 Intentions
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "              Intentions"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): Intention for DC3/default/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Intention for DC3/cernunnos/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (default): Intention for DC3/default/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Intention for DC3/cernunnos/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Intention for DC4/default/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4-default-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Intention for DC4/taranis/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/intentions/dc4-taranis-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Intention for DC4/default/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4-default-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Intention for DC4/taranis/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/intentions/dc4-taranis-unicorn_tp_backend-allow.yaml


echo -e ""

# ------------------------------------------
#           External Services
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "           External Services"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): External Service-default - Example.com  ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com.yaml

kubectl --context $KDC3 create namespace externalz

echo -e "${GRN}DC3 (default): External Service-defaults - whatismyip  ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-whatismyip.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-whatismyip.yaml

# --------
# Intentions
# --------

echo -e "${GRN}DC3 (default): Service Intention - External Service - Example.com ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/external-example_https-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/external-example_https-allow.yaml

echo -e "${GRN}DC3 (default): Service Intention - External Service - Example.com ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/external-whatismyip-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/external-whatismyip-allow.yaml

# ------------------------------------------
#           Terminating Gateway
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "           Terminating Gateway"
echo -e "------------------------------------------${NC}"

# Add the terminating-gateway ACL policy to the TGW Role, so it can actually service:write the services it fronts. DUMB.
consul acl policy create -name "Terminating-Gateway-Service-Write" -rules @./kube/configs/dc3/acl/terminating-gateway.hcl -http-addr="$DC3"
export DC3_TGW_ROLEID=$(consul acl role list -http-addr="$DC3" -format=json | jq -r '.[] | select(.Name == "consul-terminating-gateway-acl-role") | .ID')
consul acl role update -id $DC3_TGW_ROLEID -policy-name "Terminating-Gateway-Service-Write" -http-addr="$DC3"

echo -e "${GRN}DC3 (default): Terminating-Gateway config   ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/tgw/terminating-gateway.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/tgw/terminating-gateway.yaml

# ------------------------------------------
# Service Sameness Group Application (unicorn-ssg-frontend)
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " Service Sameness Group Application (unicorn-ssg-frontend)"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): Apply service-resolver: unicorn-backend/unicorn ${NC}"    # Matches the upstream unicorn-backend and applies the SSG.
kubectl apply --context $KDC3 -f ./kube/configs/dc3/service-resolver/service-resolver-unicorn_sameness.yaml

echo -e "${GRN}DC3 (default): Apply Unicorn-ssg-frontend serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/unicorn-ssg_frontend.yaml

# We can't create a new intentions file for SGs where an intention for the upstream service already exists. Have to just modify the original intention file.

# Exported Services
#   unicorn-tp-backend is added to the exported-services configs using "SamenessGroup: ssg-unicorn".
#   Exported on dc3-cernunnos, dc4-default, and dc4-taranis

# ==========================================
#              Outputs
# ==========================================

if $ARG_EKSONLY;
  then
    export UNICORN_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')
    # export UNICORN_SSG_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')

    while true; do    # Trying this instead of the above, since we keep hitting race conditions in the EKSOnly outputs.
      SSG_HOSTNAME=$(kubectl get svc unicorn-ssg-frontend -n unicorn --context $KDC3 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      SSG_PORT=$(kubectl get svc unicorn-ssg-frontend -n unicorn --context $KDC3 -o jsonpath='{.spec.ports[0].port}')

      if [ ! -z "$SSG_HOSTNAME" ]; then
        UNICORN_SSG_FRONTEND_UI_ADDR=http://$SSG_HOSTNAME:$SSG_PORT
        break
      fi

      echo "Waiting for the SSG load balancer to get an ingress hostname..."
      sleep 5
    done

echo -e "$(cat << EOF
${GRN}
------------------------------------------
            EKSOnly Outputs
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: http://$DC3_LB_IP:8500
 ${YELL}DC4${NC}: http://$DC4_LB_IP:8500

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Fake Service UI addresses: ${NC}
 ${YELL}Unicorn-Frontend:${NC} $UNICORN_FRONTEND_UI_ADDR/ui/
 ${YELL}Unicorn-SSG-Frontend:${NC} $UNICORN_SSG_FRONTEND_UI_ADDR/ui/
If this is blank - run do this. EKS is being slow and I need to build a check: kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r 'http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)'

${GRN}Export ENV Variables ${NC}
 export DC3=http://$DC3_LB_IP:8500
 export DC4=http://$DC4_LB_IP:8500

${GRN}Port forwards to map services / UI to traditional Doctor Consul local ports: ${NC}
 kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-frontend 11000:8000 > /dev/null 2>&1 &
 kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-ssg-frontend 11001:8001  > /dev/null 2>&1 &
 kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &
 kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &

$(printf "${RED}"'Happy Consul'\''ing!!! '"${NC}\n")

Before running ${YELL}terraform destroy${NC}, first run ${YELL}./kill.sh -eksonly${NC} to prevent AWS from horking. Trust me.
EOF
)"

  else

echo -e "$(cat << EOF
${GRN}------------------------------------------
            K3d Outputs
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: https://127.0.0.1:8502/ui/
 ${YELL}DC4${NC}: https://127.0.0.1:8503/ui/

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Fake Service UI addresses: ${NC}
 ${YELL}Unicorn-Frontend:${NC} http://127.0.0.1:11000/ui/
 ${YELL}Unicorn-SSG-Frontend:${NC} http://localhost:11001/ui/

${GRN}Export ENV Variables ${NC}
 export DC3=https://127.0.0.1:8502
 export DC4=https://127.0.0.1:8503
EOF
)"

fi

### Experimental args to help with the initial figuring out of Vault
if [[ "$*" == "vault-setup" ]]
  then
    InstallConsulDC4
    InstallConsulDC4_P1
fi

if [[ "$*" == "vault-kill" ]]
  then
    k3d cluster delete dc4
    k3d cluster delete dc4-p1
fi

# ------------------------------------------
#     Consul API Gateway config script
# ------------------------------------------

./apigw-config.sh

# ==========================================
#              Useful Commands
# ==========================================

# k3d cluster list
# k3d cluster delete dc3

# kubectl get secret peering-token --namespace consul --output yaml


# https://github.com/ppresto/terraform-azure-consul-ent-aks
# https://github.com/ppresto/terraform-azure-consul-ent-aks/blob/main/PeeringDemo-EagleInvestments.md

# consul-k8s proxy list -n unicorn | grep unicorn-frontend | cut -f1 | xargs -I {} consul-k8s proxy read {} -n unicorn

# kubectl exec -nunicorn -it unicorn-frontend-97848474-lltd7  -- /usr/bin/curl localhost:19000/listeners
# kubectl exec -nunicorn -it unicorn-frontend-97848474-lltd7  -- /usr/bin/curl localhost:19000/clusters | vsc
# kubectl exec -nunicorn -it unicorn-backend-548d9999f6-khnxt  -- /usr/bin/curl localhost:19000/clusters | vsc

# consul-k8s proxy list -n unicorn | grep unicorn-frontend | cut -f1 | tr -d " " | xargs -I {} kubectl exec -nunicorn -it {} -- /usr/bin/curl -s localhost:19000/clusters
# consul-k8s proxy list -n unicorn | grep unicorn-frontend | cut -f1 | tr -d " " | xargs -I {} kubectl exec -nunicorn -it {} -- /usr/bin/curl -s localhost:19000/config_dump
# consul-k8s proxy list -n unicorn | grep unicorn-backend | cut -f1 | tr -d " " | xargs -I {} kubectl exec -nunicorn -it {} -- /usr/bin/curl -s localhost:19000/clusters
# consul-k8s proxy list -n unicorn | grep unicorn-backend | cut -f1 | tr -d " " | xargs -I {} kubectl exec -nunicorn -it {} -- /usr/bin/curl -s localhost:19000/config_dump

# consul peering generate-token -name dc3-default -http-addr="$DC1"



# -------------------------------------------
#      Peering with CRDs - works-ish
# -------------------------------------------

# consul partition create -name "peering-test" -http-addr="$DC3"
# consul partition create -name "peering-test" -http-addr="$DC4"

# kubectl apply --context $KDC4 -f ./kube/configs/peering/peering-acceptor_dc3-default_dc4-default.yaml
# kubectl --context $KDC4 get secret peering-token-dc3-default-dc4-default -nconsul --output yaml > ./tokens/peering-token-dc3-default-dc4-default.yaml

# kubectl apply --context $KDC3 -f ./tokens/peering-token-dc3-default-dc4-default.yaml
# kubectl apply --context $KDC3 -f ./kube/configs/peering/peering-dialer_dc3-default_dc4-default.yaml

