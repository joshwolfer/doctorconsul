#!/bin/bash

set -e

export CONSUL_HTTP_TOKEN=root

# HOME=$(pwd)
# For some stupid reason k3d won't allow "./" in the path for config files so we have to do this non-sense for the Calico config to load...

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"
DC3="https://127.0.0.1:8502"
DC4="https://127.0.0.1:8503"
DC5=""
DC6=""

KDC3="k3d-dc3"
KDC3_P1="k3d-dc3-p1"
KDC4="k3d-dc4"
KDC4_P1="k3d-dc4-p1"

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m' 

if [[ "$*" == *"help"* ]]
  then
    echo -e "Syntax: ./k3d-config.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -nopeer      Bypass cluster peering. Useful when launching k3d without the rest of Doctor Consul (Compose environment)"
    echo "  -update      Update K3d to the latest version"
    exit 0
fi

if [[ "$*" == *"-update"* ]]
  then
    echo ""
    echo -e "${GRN}Updating K3d... ${NC}"
    echo -e "${YELL}Pulling from https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh ${NC}"
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    echo ""
    exit 0
fi


# Start docker service if it's not running:

OS_NAME=$(uname)

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

# (4/18/23) New K3d errors regarding cgroups fixed via %UserProfile%\.wslconfig
# 
# [wsl2]
# kernelCommandLine = cgroup_no_v1=all cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
# 
# wsl.exe --shutdown

# ==========================================
#             Setup K3d clusters
# ==========================================

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " Download Calico Config files"
echo -e "------------------------------------------${NC}"

# Fetch the Calico setup file to use with k3d. 
# K3D default CNI (flannel) doesn't work with Consul Tproxy / DNS proxy

curl -s https://k3d.io/v5.0.1/usage/advanced/calico.yaml -o ./kube/calico.yaml

# ------------------------------------------
#                    DC3
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "         Setup K3d cluster (DC3)"
echo -e "==========================================${NC}"

k3d cluster create dc3 --network doctorconsul_wan \
    --api-port 127.0.0.1:6443 \
    -p "8502:443@loadbalancer" \
    -p "11000:8000" \
    -p "9091:9090" \
    --k3s-arg '--flannel-backend=none@server:*' \
    --k3s-arg="--disable=traefik@server:0"

    kubectl apply --context=$KDC3 -f ./kube/calico.yaml 
    
    # --volume "$HOME/kube/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" \
    # -p "11000:8000"    DC3/unicorn/unicorn-frontend (fake service UI)
    # -p "9091:9090"     Prometheus UI

# ------------------------------------------
#            DC3-P1 cernunnos
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "         Setup K3d cluster (DC3-P1 cernunnos)"
echo -e "==========================================${NC}"

k3d cluster create dc3-p1 --network doctorconsul_wan \
    --api-port 127.0.0.1:6444 \
    -p "8443:8443" \
    --k3s-arg="--disable=traefik@server:0" \
    --k3s-arg '--flannel-backend=none@server:*'
    
    kubectl apply --context=$KDC3_P1 -f ./kube/calico.yaml 

    # --volume "$HOME/kube/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml"  

    # Disable flannel
    # install Calico (tproxy compatability)

    # -p "8443:8443"      api-gateway ingress
    # -p "12000:8000"     reserved for fakeservice something


# ------------------------------------------
#                    DC4
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "         Setup K3d cluster (DC4)"
echo -e "==========================================${NC}"

k3d cluster create dc4 --network doctorconsul_wan \
    --api-port 127.0.0.1:6445 \
    -p "8503:443@loadbalancer" \
    -p "12000:8000" \
    -p "9092:9090" \
    --k3s-arg '--flannel-backend=none@server:*' \
    --k3s-arg="--disable=traefik@server:0"

    kubectl apply --context=$KDC4 -f ./kube/calico.yaml 

#  12000 > 8000 - whatever app UI   
#  local 8503 > 443 - Consul UI 

# ------------------------------------------
#            DC4-P1 taranis
# ------------------------------------------

echo -e "${GRN}"
echo -e "=========================================="
echo -e "    Setup K3d cluster (DC4-P1 taranis)"
echo -e "==========================================${NC}"

k3d cluster create dc4-p1 --network doctorconsul_wan \
    --api-port 127.0.0.1:6446 \
    --k3s-arg="--disable=traefik@server:0" \
    --k3s-arg '--flannel-backend=none@server:*'
    
    kubectl apply --context=$KDC4_P1 -f ./kube/calico.yaml 

# ==========================================
#            Setup Consul-k8s
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "           Setup Consul-k8s"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}Adding HashiCorp Helm Chart:${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com

echo -e ""
echo -e "${GRN}Updating Helm Repos:${NC}"
helm repo update

echo -e ""
echo -e "${YELL}Currently installed Consul Helm Version:${NC}"
helm search repo hashicorp/consul --versions | head -n2

# Should probably pin a specific helm chart version, but I love living on the wild side!!!

echo -e ""
echo -e "${GRN}Writing latest Consul Helm values to disk...${NC}"
helm show values hashicorp/consul > ./kube/helm/latest-complete-helm-values.yaml

# ==========================================
#         Install Consul-k8s (DC3)
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Consul-k8s (DC3)"
echo -e "==========================================${NC}"

echo -e "${YELL}Switching Context to DC3... ${NC}"
kubectl config use-context $KDC3

echo -e ""
echo -e "${GRN}DC3: Create Consul namespace${NC}"

kubectl create namespace consul

echo -e ""
echo -e "${GRN}DC3: Create secrets for gossip, ACL token, Consul License:${NC}"

kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"
kubectl create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root"
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"


echo -e ""
echo -e "${GRN}DC3: Helm consul-k8s install${NC}"

helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --debug
# helm upgrade consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --debug

echo -e ""
echo -e "${GRN}DC3: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC}"

kubectl get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc3-credentials.yaml
kubectl get secret consul-ca-key -n consul -o yaml > ./tokens/dc3-ca-key.yaml
kubectl get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc3-partition-token.yaml

# ==========================================
# Install Consul-k8s (DC3 Cernunnos Partition)
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "Install Consul-k8s (DC3 Cernunnos Partition)"
echo -e "==========================================${NC}"

echo -e "${YELL}Switching Context to DC3-P1... ${NC}"
kubectl config use-context $KDC3_P1

echo -e ""
echo -e "${GRN}DC3-P1 (Cernunnos): Create Consul namespace${NC}"

kubectl create namespace consul

echo -e ""
echo -e "${GRN}DC3-P1 (Cernunnos): Install Kube secrets (CA cert / key, bootstrap token, partition token) extracted from DC3:${NC}"

kubectl apply -f ./tokens/dc3-credentials.yaml
kubectl apply -f ./tokens/dc3-ca-key.yaml
kubectl apply -f ./tokens/dc3-partition-token.yaml
# ^^^ Consul namespace is already embedded in the secret yaml.

echo -e ""
echo -e "${GRN}DC3-P1 (Cernunnos): Create secret Consul License:${NC}"

# kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"   # It looks like we don't need this for Dataplane...
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"

echo -e ""
echo -e "${GRN}Discover the DC3 external load balancer IP:${NC}"

export DC3_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
echo -e "${YELL}DC3 External Load Balancer IP is:${NC} $DC3_LB_IP"

echo -e ""
echo -e "${GRN}Discover the DC3 Cernunnos cluster Kube API${NC}"

export DC3_K8S_IP="https://$(kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"
echo -e "${YELL}DC3 K8s API address is:${NC} $DC3_K8S_IP"

  # kubectl get services --selector="app=consul,component=server" --namespace consul --output jsonpath="{range .items[*]}{@.status.loadBalancer.ingress[*].ip}{end}"
  #  ^^^ Potentially better way to get list of all LB IPs, but I don't care for Doctor Consul right now.

  # kubectl config view --output "jsonpath={.clusters[?(@.name=='$KDC3_P1')].cluster.server}"
  # ^^^ Don't actually need this because the k3d kube API is exposed on via the LB on 6443 already.

echo -e ""
echo -e "${GRN}DC3-P1 (Cernunnos): Helm consul-k8s install${NC}"

helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul \
  --set externalServers.k8sAuthMethodHost=$DC3_K8S_IP \
  --set externalServers.hosts[0]=$DC3_LB_IP \
  --debug
# ^^^ --dry-run to test variable interpolation... if it actually worked.

# ==========================================
#         Install Consul-k8s (DC4)
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Consul-k8s (DC4)"
echo -e "==========================================${NC}"

echo -e "${YELL}Switching Context to DC4... ${NC}"
kubectl config use-context $KDC4

echo -e ""
echo -e "${GRN}DC4: Create Consul namespace${NC}"

kubectl create namespace consul

echo -e ""
echo -e "${GRN}DC4: Create secrets for gossip, ACL token, Consul License:${NC}"

kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"
kubectl create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root"
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"


echo -e ""
echo -e "${GRN}DC4: Helm consul-k8s install${NC}"

helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul --debug

echo -e ""
echo -e "${GRN}DC4: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC}"

kubectl get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc4-credentials.yaml
kubectl get secret consul-ca-key -n consul -o yaml > ./tokens/dc4-ca-key.yaml
kubectl get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc4-partition-token.yaml

# ==========================================
# Install Consul-k8s (DC4 Taranis Partition)
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "Install Consul-k8s (DC4 taranis Partition)"
echo -e "==========================================${NC}"

echo -e "${YELL}Switching Context to DC4-P1... ${NC}"
kubectl config use-context $KDC4_P1

echo -e ""
echo -e "${GRN}DC4-P1 (Taranis): Create Consul namespace${NC}"

kubectl create namespace consul

echo -e ""
echo -e "${GRN}DC4-P1 (Taranis): Install Kube secrets (CA cert / key, bootstrap token, partition token) extracted from DC4:${NC}"

kubectl apply -f ./tokens/dc4-credentials.yaml
kubectl apply -f ./tokens/dc4-ca-key.yaml
kubectl apply -f ./tokens/dc4-partition-token.yaml
# ^^^ Consul namespace is already embedded in the secret yaml.

echo -e ""
echo -e "${GRN}DC4-P1 (Taranis): Create secret Consul License:${NC}"

# kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"   # It looks like we don't need this for Dataplane...
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"

echo -e ""
echo -e "${GRN}Discover the DC4 external load balancer IP:${NC}"

export DC4_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
echo -e "${YELL}DC4 External Load Balancer IP is:${NC} $DC4_LB_IP"

echo -e ""
echo -e "${GRN}Discover the DC4 Taranis cluster Kube API${NC}"

export DC4_K8S_IP="https://$(kubectl get node k3d-dc4-p1-server-0 --context $KDC4_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"
echo -e "${YELL}DC4 K8s API address is:${NC} $DC4_K8S_IP"


echo -e ""
echo -e "${GRN}DC4-P1 (Taranis): Helm consul-k8s install${NC}"

helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul \
  --set externalServers.k8sAuthMethodHost=$DC4_K8S_IP \
  --set externalServers.hosts[0]=$DC4_LB_IP \
  --debug
# ^^^ --dry-run to test variable interpolation... if it actually worked.


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
kubectl apply --namespace consul -f ./kube/prometheus/dc3-prometheus-service.yaml

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

k3dPeering () {

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
#            Check for -nopeer
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

if [[ "$*" == *"-nopeer"* ]]
  then
    echo ""
    echo -e "${RED} *** VM-based Cluster Peering Bypassed ${NC}"
    echo ""
  else
    k3dPeering
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

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Unicorn Application"
echo -e "==========================================${NC}"


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

# ------------------------------------------
#     Services
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "        Launch Kube Configs"
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
#                    Defaults
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "               Defaults"
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
#                 Intentions
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "              Intentions"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (default): Create Allow intention DC3/default/unicorn/unicorn-frontend > DC3/default/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Intention allow DC3/default/unicorn/unicorn-frontend to DC3/cernunnos/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (default): Create Allow intention DC3/default/unicorn/unicorn-frontend > DC3/default/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Intention allow DC3/default/unicorn/unicorn-frontend to DC3/cernunnos/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Create Allow intention DC3/default/unicorn/unicorn-frontend > DC4/default/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Intention allow DC3/default/unicorn/unicorn-frontend to DC4/taranis/unicorn/unicorn-backend ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/intentions/dc4-taranis-unicorn_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (default): Create Allow intention DC3/default/unicorn/unicorn-frontend > DC4/default/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4-unicorn_tp_backend-allow.yaml

echo -e ""
echo -e "${GRN}DC4 (taranis): Intention allow DC3/default/unicorn/unicorn-frontend to DC4/taranis/unicorn/unicorn-tp-backend ${NC}"
kubectl apply --context $KDC4_P1 -f ./kube/configs/dc4/intentions/dc4-taranis-unicorn_tp_backend-allow.yaml


# ------------------------------------------
#           Exported-services
# ------------------------------------------

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

