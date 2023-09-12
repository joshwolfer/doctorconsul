#!/bin/bash

set -e

source ./scripts/functions.sh

for arg in "$@"; do
    if [[ $arg == "-eks" ]]; then
        ARG_EKSONLY=true
    fi
done

echo -e ""
echo -e "${YELL}Currently installed Vault Helm Version:${NC}"
helm search repo hashicorp/vault --versions | head -n2

echo -e ""
echo -e "${GRN}Writing latest Vault Helm values to disk...${NC}"
helm show values hashicorp/vault > ./kube/vault/vault-latest-complete-helm-values.yaml

# ====================================================================================
#                        Install Vault into Kubernetes
# ====================================================================================

install_vault() {      # Example: install_vault $KDC3 [-eks]

  CONTEXT=$1                    # Kube context to install Vault into
  DC_PREFIX=${CONTEXT#k3d-}     # Takes the CONTEXT and removes k3d- from it. Used in helm filenames later.

  echo -e "${GRN}"
  echo -e "=========================================="
  echo -e "   Install Vault into Kubernetes ($DC_PREFIX)"
  echo -e "==========================================${NC}"

  echo -e ""
  echo -e "${GRN}$DC_PREFIX: Create Vault namespace${NC}"

  kubectl --context $CONTEXT create namespace vault
  # kubectl --context $KDC4 delete namespace vault

  echo -e ""
  echo -e "${GRN}$DC_PREFIX: Helm Vault install${NC}"

  helm install vault hashicorp/vault -f ./kube/vault/$DC_PREFIX-vault-helm-values.yaml --namespace vault --kube-context $CONTEXT
  # helm delete vault --namespace vault

  rm ./tokens/vault-$DC_PREFIX-root.token -f
  # Remove previous vault token




  echo ""
  echo -e "${GRN}$DC_PREFIX Vault Kube service is ready ${NC}"
  echo ""

  wait_for_kube_service vault-ui vault $CONTEXT 10 VAULT_HOST
  echo ""

  # ------------------------------------------
  #   Discover the actual VAULT API Address
  # ------------------------------------------

  export VAULT_ADDR="http://$VAULT_HOST:8200"
  echo -e "${YELL}VAULT_ADDR is:${NC} $VAULT_ADDR"
  # echo -e "ARG_EKSONLY is $ARG_EKSONLY"


  #  Wait until the Vault API is responding
  until curl -s $VAULT_ADDR/v1/sys/health --connect-timeout 1 | jq -r .initialized | grep false &>/dev/null; do
    echo -e "${RED}Waiting for $DC_PREFIX Vault API to be ready... This takes longer than you'd think. ${NC}"
    sleep 4
  done

  vault operator init -key-shares=1 -key-threshold=1 -format=json | tee >(jq -r .root_token > ./tokens/vault-$DC_PREFIX-root.token) >(jq -r .unseal_keys_b64[0] > ./tokens/vault-$DC_PREFIX-unseal.key) >/dev/null
  export VAULT_TOKEN=$(cat ./tokens/vault-$DC_PREFIX-root.token)
  export VAULT_UNSEAL=$(cat ./tokens/vault-$DC_PREFIX-unseal.key)

  # ------------------------------------------
  #   Outputs
  # ------------------------------------------

  echo ""
  echo -e "${GRN}($DC_PREFIX) Vault Details: ${NC}"
  echo -e "${YELL}Vault API Address:${NC} $VAULT_ADDR"
  echo -e "${YELL}Vault root token:${NC} $VAULT_TOKEN"
  echo -e "${YELL}Vault Unseal Key:${NC} $VAULT_UNSEAL"
  echo ""
  echo -e "${GRN}Shell Env Variables:${NC}"
  echo "export VAULT_ADDR=$VAULT_ADDR"
  echo "export VAULT_TOKEN=$VAULT_TOKEN"
  echo ""

  # ------------------------------------------
  #            Unseal Vault
  # ------------------------------------------

  sleep 5     # wait for DNS to propagate out of AWS. This keeps failing
  echo -e "${GRN}Unsealing Vault:${NC}"
  vault operator unseal $VAULT_UNSEAL
  echo ""

}

install_vault $1

# ====================================================================================
#                      Configure Vault for Stuff (DC4)
# ====================================================================================

# echo -e "${GRN}"
# echo -e "=========================================="
# echo -e "   DC4: Vault for Consul Secrets Backend "
# echo -e "==========================================${NC}"

# vault secrets enable -path=consul kv-v2
# vault secrets enable pki

# # export VAULT_AUTH_METHOD_NAME=kubernetes-dc4
# # export VAULT_SERVER_HOST=$VAULT_ADDR

# vault auth enable -path=kubernetes-dc4 kubernetes


# export DC4_K8S_IP="https://$(kubectl get node k3d-dc4-server-0 --context $KDC4 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6445"
# ### This env name is going to clash with the kube-config which uses the same "DC4_K8S_IP", but really refers to dc4-p1

# vault write auth/kubernetes/config \
#     token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
#     kubernetes_host="$DC4_K8S_IP" \
#     kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# # ^^^ I give up. I'm tired of trying to figure out our docs. I'm pausing this project and coming back later.



