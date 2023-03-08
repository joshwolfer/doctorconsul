#!/bin/bash

set -e

export CONSUL_HTTP_TOKEN=root

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"
DC3="https://127.0.0.1:8502"
DC4=""
DC5=""
DC6=""

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
NC='\033[0m' # No Color

# ==========================================
#         Setup K3d cluster (DC3)
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "           Setup K3d cluster"
echo -e "==========================================${NC}"

k3d cluster create dc3 --network doctorconsul_wan \
    --api-port 127.0.0.1:6443 \
    -p "8502:443@loadbalancer" \
    --k3s-arg="--disable=traefik@server:0" \

# ==========================================
#            Install Consul-k8s
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "           Install Consul-k8s"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}DC3: Create Consul namespace${NC}"

kubectl create namespace consul

echo -e ""
echo -e "${GRN}DC3: Create secrets for gossip, ACL token, Consul License:${NC}"

kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"
kubectl create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root"
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"

# Should update the helm chart to make sure it's on the latest ver, or possibly pin the version...

echo -e ""
echo -e "${GRN}DC3: Helm consul-k8s install${NC}"
helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --debug

# ==========================================
#              Consul configs
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "             Consul configs"
echo -e "==========================================${NC}"

## Wait for DC3 to electe a leader before starting resource provisioning

echo -e ""
echo -e "${GRN}Wait for DC3 to electer a leader before starting resource provisioning${NC}"

until curl -s -k ${DC3}/v1/status/leader | grep 8300; do
  echo -e "${RED}Waiting for DC3 Consul to start${NC}"
  sleep 1
done

echo -e ""
echo -e "${GRN}DC3: MGW Peering over Gateways${NC}"

kubectl apply -f ./kube/configs/peering/mgw-peering.yaml

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

# ------------------------------------------
# Peer DC3/default -> DC1/default
# ------------------------------------------

echo -e ""
echo -e "${GRN}DC3/default -> DC1/default${NC}"

consul peering generate-token -name dc3-default -http-addr="$DC1" > tokens/peering-dc1_default-dc3-default.token

kubectl create secret generic peering-token-dc1-default-dc3-default --namespace consul --from-literal=data=$(cat tokens/peering-dc1_default-dc3-default.token)
kubectl label secret peering-token-dc1-default-dc3-default -n consul "consul.hashicorp.com/peering-token=true"
kubectl apply --namespace consul -f ./kube/configs/peering/peering_dc1-default_dc3-default.yaml

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

# ==========================================
#              Usefull Commands
# ==========================================

# k3d cluster list
# k3d cluster delete dc3

# kubectl get secret peering-token --namespace consul --output yaml


# https://github.com/ppresto/terraform-azure-consul-ent-aks
# https://github.com/ppresto/terraform-azure-consul-ent-aks/blob/main/PeeringDemo-EagleInvestments.md