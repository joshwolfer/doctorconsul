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
helm show values hashicorp/vault > ./kube/vault/vault-latest-complete-helm-values.yaml

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

kubectl --context $KDC4 create namespace vault
# kubectl --context $KDC4 delete namespace vault

echo -e ""
echo -e "${GRN}DC4: Helm Vault install${NC}"

helm install vault hashicorp/vault -f ./kube/vault/dc4-vault-helm-values.yaml --namespace vault --kube-context $KDC4
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

if [[ "$*" == "-eksonly" ]];
  then
    export VAULT_ADDR=""  ## Need to get the EKSOnly address here.
  else
    export VAULT_ADDR="http://$(kubectl --context $KDC4 get svc vault-ui -o json --namespace vault | jq -r .status.loadBalancer.ingress[0].ip):8200"
    # Get the HTTP Vault API
    # In AWS this will likely need to be an address, not an IP
fi

until curl -s $VAULT_ADDR/v1/sys/health --connect-timeout 1 | jq -r .initialized | grep false &>/dev/null; do
  echo -e "${RED}Waiting for Vault API to be ready...${NC}"
  sleep 1.5
done

vault operator init -key-shares=1 -key-threshold=1 -format=json | tee >(jq -r .root_token > ./tokens/vault-root.token) >(jq -r .unseal_keys_b64[0] > ./tokens/vault-unseal.key) >/dev/null
export VAULT_TOKEN=$(cat ./tokens/vault-root.token)
export VAULT_UNSEAL=$(cat ./tokens/vault-unseal.key)

echo ""
echo -e "${GRN}Vault Details: ${NC}"
echo -e "${YELL}Vault API Address:${NC} $(echo $VAULT_ADDR)"
echo -e "${YELL}Vault root token:${NC} $(echo $VAULT_TOKEN)"
echo -e "${YELL}Vault Unseal Key:${NC} $(echo $VAULT_UNSEAL)"
echo ""
echo -e "${GRN}Shell Env Variables:${NC}"
echo "export VAULT_ADDR=$VAULT_ADDR"
echo "export VAULT_TOKEN=$VAULT_TOKEN"
echo ""

echo -e "${GRN}Unsealing Vault:${NC}"
vault operator unseal $VAULT_UNSEAL
echo ""

# ====================================================================================
#                      Configure Vault for Stuff (DC4)
# ====================================================================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "   DC4: Vault for Consul Secrets Backend "
echo -e "==========================================${NC}"

vault secrets enable -path=consul kv-v2
vault secrets enable pki

# export VAULT_AUTH_METHOD_NAME=kubernetes-dc4
# export VAULT_SERVER_HOST=$VAULT_ADDR

vault auth enable -path=kubernetes-dc4 kubernetes


export DC4_K8S_IP="https://$(kubectl get node k3d-dc4-server-0 --context $KDC4 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6445"
### This env name is going to clash with the kube-config which uses the same "DC4_K8S_IP", but really refers to dc4-p1

vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="$DC4_K8S_IP" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# ^^^ I give up. I'm tired of trying to figure out our docs. I'm pausing this project and coming back later.

