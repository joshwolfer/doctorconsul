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

echo ""

VAULT_IP=""
while true; do
  VAULT_IP=$(kubectl get svc vault-ui -o json --namespace vault | jq -r .status.loadBalancer.ingress[0].ip 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to retrieve service. Retrying...${NC}"
  elif [[ -n $VAULT_IP && $VAULT_IP != "null" ]]; then
    break
  else
    echo -e "${RED}Waiting for DC4 Vault Kube service to be ready...${NC}"
  fi
  sleep 1
done
# Had to do this complicated rigamarole because of various conditions that kept failing. This seems to work consistently. Thanks chatgpt...

echo -e "${GRN}DC4 Vault Kube service is ready ${NC}"
echo ""

export VAULT_ADDR="http://$(kubectl get svc vault-ui -o json --namespace vault | jq -r .status.loadBalancer.ingress[0].ip):8200"
# Get the HTTP Vault API
# In AWS this will likely need to be an address, not an IP

until curl -s $VAULT_ADDR/v1/sys/health --connect-timeout 1 | jq -r .initialized | grep false &>/dev/null; do
  echo -e "${RED}Waiting for Vault API to be ready...${NC}"
  sleep 1.5
done

vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r .root_token > ./tokens/vault-root.token
export VAULT_TOKEN=$(cat ./tokens/vault-root.token)

echo ""
echo -e "${GRN}Vault Details: ${NC}"
echo -e "${YELL}Vault API Address:${NC} $(echo $VAULT_ADDR)"
echo -e "${YELL}Vault root token:${NC} $(echo $VAULT_TOKEN)"
echo ""

