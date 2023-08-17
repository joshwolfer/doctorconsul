#!/bin/bash

set -e

source ./scripts/functions.sh
# ^^^ Variables and shared functions

if [[ -z "${EKSONLY_TF_STATE_FILE}" ]]; then
  export EKSONLY_TF_STATE_FILE="/home/mourne/git/EKSonly/terraform.tfstate"
  # If it's already set, don't mess with it. If it's not set, it sets it to my personal location
  # Set this to the path of the EKSOnly repo so the outputs can be read! This MUST be set correctly!!!
fi

help () {
    echo -e "Syntax: ./kube-config.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k3d-full           Integrate with full docker compose environment. Without this, only launch Consul in k3d"
    echo "  -no-k3d             Skip installing k3d - Configures k8s in a local k3d style (IE: IP based LBs)"
    echo "  -k8s-only           Only Install raw K3d clusters without Consul. Useful when you want to play with k8s alone"
    echo "  -update             Update K3d to the latest version"
    echo "  -eksonly            Sets 4 Kube Contexts to the appropriate names from EKSonly (https://github.com/ramramhariram/EKSonly)"
    echo "  -eksonly-context    Refreshes the EKSOnly Kube Contexts"
    echo "  -nuke-eksonly       Destroy the EKSOnly resources so it's safe to tf destroy"
    echo "  -no-apps            Install Consul into clusters with additional NO services"
    echo "  -debug              Run Helm installation with --debug"
    echo "  -vars               List environment variables"
    echo ""
    exit 0
}

# ------------------------------------------
#    Parse Arguments into variables
# ------------------------------------------

export ARG_K3D_FULL=false
export ARG_NO_K3D=false
export ARG_K8S_ONLY=false
export ARG_UPDATE=false
export ARG_EKSONLY=false
export ARG_EKSONLY_CONTEXT=false
export ARG_NUKE_EKSONLY=false
export ARG_NO_APPS=false
export ARG_DEBUG=false
export ARG_HELP=false
export ARG_VARS=false

if [ $# -eq 0 ]; then
  echo ""
else
  for arg in "$@"; do
    case $arg in
      -k3d-full)
        ARG_K3D_FULL=true
        ;;
      -no-k3d)
        ARG_NO_K3D=true
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
      -vars)
        ARG_VARS=true
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

if $ARG_VARS; then       # Output a list of environemnt variables that can be copypasta'd back into the terminals
  ./scripts/vars.sh
  exit 0
fi

if [ "$ARG_EKSONLY" = "true" ] || [ "$ARG_EKSONLY_CONTEXT" = "true" ]; then     # Update the Kube contexts for EKSOnly
  update_aws_context
fi

if $ARG_EKSONLY_CONTEXT; then         # If we're only re-genning the AWS EKS contexts, exit gracefully.
  echo -e "${GRN}Exiting (-eksonly-context)${NC}"
  echo ""
  exit 0
fi

if $ARG_NUKE_EKSONLY; then           # Run AWS EKSonly nuke script if commanded
  nuke_aws_eksonly
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

if $ARG_K8S_ONLY; then echo -e "${RED} Building K3d clusters ONLY (-k8s-only) ${NC}"; fi

if [[ $PWD == *"doctorconsul"* ]]; then rm -f ./logs/*.log; fi
# Delete previous logs

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

if $ARG_EKSONLY || $ARG_NO_K3D; then
    echo ""
    echo -e "${RED}Skipping k3d cluster install${NC}"
    echo ""
else
    ./scripts/k3d-config.sh
fi

# ==============================================================================================================================
# ==============================================================================================================================
#
#                           Consul is actually installed into Kube clusters from HERE on
#
# ==============================================================================================================================
# ==============================================================================================================================

./scripts/helm-install.sh
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
echo -e ""

wait_for_consul_connect_inject_service $KDC3 "consul-connect-injector" "DC3 (default)"
wait_for_consul_connect_inject_service $KDC3_P1 "consul-cernunnos-connect-injector" "DC3 (cernunnos)"
wait_for_consul_connect_inject_service $KDC4 "consul-connect-injector" "DC4 (default)"
wait_for_consul_connect_inject_service $KDC4_P1 "consul-taranis-connect-injector" "DC4 (taranis)"


  # ------------------------------------------
  #   Pull in address information from sub processes
  # ------------------------------------------

  # TLDR; Because the helm installation functions are launched as background shells to build in parallel (performance reasons)
  # Environment variables cannot be passed back to this parent script. So the sub shells write these addresses to temp disk and
  # we re-assign the variables here. MAGIC.

export DC3_LB_IP=$(cat ./tokens/dc3_lb_ip.txt)
export DC3_P1_K8S_IP=$(cat ./tokens/dc3_p1_k8s_ip.txt)

export DC4_LB_IP=$(cat ./tokens/dc4_lb_ip.txt)
export DC4_P1_K8S_IP=$(cat ./tokens/dc4_p1_k8s_ip.txt)

export DC3="http://$DC3_LB_IP:8500"
export DC4="http://$DC4_LB_IP:8500"
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
#                                                     Cluster Peering
# ==============================================================================================================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

if $ARG_K3D_FULL;
  then
    k3dPeeringToVM
    # Peers the local k3d clusters to the doctor consul docker compose clusters DC1 / DC2 (they must be running, obviously)
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

# -------------------------------------------
#      Peering with CRDs - works-ish
# -------------------------------------------

# consul partition create -name "peering-test" -http-addr="$DC3"
# consul partition create -name "peering-test" -http-addr="$DC4"

# kubectl apply --context $KDC4 -f ./kube/configs/peering/peering-acceptor_dc3-default_dc4-default.yaml
# kubectl --context $KDC4 get secret peering-token-dc3-default-dc4-default -nconsul --output yaml > ./tokens/peering-token-dc3-default-dc4-default.yaml

# kubectl apply --context $KDC3 -f ./tokens/peering-token-dc3-default-dc4-default.yaml
# kubectl apply --context $KDC3 -f ./kube/configs/peering/peering-dialer_dc3-default_dc4-default.yaml


# ==============================================================================================================================
#                                                     Applications / Deployments
# ==============================================================================================================================

if $ARG_NO_APPS;
  then
    ./scripts/outputs.sh
    # If No apps should be installed, display the basic outputs and GTFO!
    exit 0
fi

# ------------------------------------------
#  Modify the service yaml to pull images on EKS vs k3d local
# ------------------------------------------

# The Fakeservice app yaml is all set to use a local k3d registry by default.
# This makes it so the docker image addresses are changed to public dockerhub if installing into EKSonly (AWS).
# And switches them back to k3d local if no argument is provided.
# This is a messy way of doing it, but I don't see a better way, without having to manage multiple sets of files since templating in YAML is a pain in the ass.

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

# This is turned on later with the external services config. Just FYI. Since it's scoped to the entire partition, we can't mix and match.

# ------------------------------------------
#          Unicorn Application
# ------------------------------------------

./scripts/app-unicorn.sh
# Launch script to build out all the Unicorn application components


# ------------
#  Exported Services
# ------------

# WARNING: Exported services are defined in the unicorn-app.sh script to provision them in the correct order.
# There can only be ONE exported-services config per partition.
# If more need t be added, put the into the ./scripts/unicorn-app.sh script, or you're going to stomp the existing exported-services config.
# This is being fixed in Consul V2. But until then, it's only 1 config per partition!!!.

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

# ==============================================================================================================================
#                                      External Services and Terminating Gateway Stuff
# ==============================================================================================================================

# ------------------------------------------
#  External Services - externalz-alpha Application
# ------------------------------------------

echo -e "${YELL}Running the Externalz application script:${NC} ./scripts/externalz-app.sh"
./scripts/app-externalz.sh
# Launch the externalz applications script to provision the externalz application that consumes external services

#  ------------------------------------------
#  External Services - externalz-alpha Application
# ------------------------------------------

echo -e "${YELL}Running the Sheol application script:${NC} ./scripts/app-sheol.sh"
./scripts/app-sheol.sh

# ------------------------------------------
#           Terminating Gateway
# ------------------------------------------

./scripts/terminating-gateway.sh
# Launch TGWs:
    # DC3/default/terminating-gateway
    # DC4/sheol/sheol-tgw

# ==============================================================================================================================
#                                                     Consul API Gateway
# ==============================================================================================================================

./scripts/apigw-config.sh

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

./scripts/outputs.sh                   # Outputs script the generates outputs for K3d / EKSOnly

