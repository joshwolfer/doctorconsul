#!/bin/bash

set -e

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m'

KDC3="k3d-dc3"
KDC3_P1="k3d-dc3-p1"
KDC4="k3d-dc4"
KDC4_P1="k3d-dc4-p1"

echo -e ""
echo -e "${YELL}Currently installed Vault Helm Version:${NC}"
helm search repo hashicorp/vault --versions | head -n2

echo -e ""
echo -e "${GRN}Writing latest Vault Helm values to disk...${NC}"
helm show values hashicorp/vault > ./kube/vault/latest-complete-helm-values.yaml

# ====================================================================================
#                      Install Vault into Kubernetes (DC4)
# ====================================================================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "   Install Vault into Kubernetes (DC4)"
echo -e "==========================================${NC}"

echo -e "${YELL}Switching Context to DC4... ${NC}"
kubectl config use-context $KDC4

echo -e ""
echo -e "${GRN}DC4: Create Vault namespace${NC}"

kubectl create namespace vault
# kubectl delete namespace vault

echo -e ""
echo -e "${GRN}DC4: Helm Vault install${NC}"

helm install vault hashicorp/vault -f ./kube/vault/dc4-helm-values.yaml --namespace vault
# helm delete vault --namespace vault

rm ./tokens/vault-root.token -f
# Remove previous vault token

IP=""
until [[ $IP && $IP != "null" ]]; do
  IP=$(kubectl get svc vault-ui -o json --namespace vault | jq -r .status.loadBalancer.ingress[0].ip)
  if [[ -z $IP || $IP == "null" ]]; then
    echo -e "${RED}Waiting for DC4 vault service to be ready...${NC}"
    sleep 1
    IP=""
  fi
done

VAULT_ADDR="http://$(kubectl get svc vault-ui -o json --namespace vault | jq -r .status.loadBalancer.ingress[0].ip):8200"
# Get the HTTP Vault API
# In AWS this will likely need to be an address, not an IP

vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r .root_token > ./tokens/vault-root.token
export VAULT_TOKEN=$(cat ./tokens/vault-root.token)

echo ""
echo -e "${GRN}Vault Details: ${NC}"
echo -e "${YELL}Vault API Address:${NC} $(echo $VAULT_ADDR)"
echo -e "${YELL}Vault root token:${NC} $(echo $VAULT_TOKEN)"
echo ""

