#!/bin/bash

set -e

export CONSUL_HTTP_TOKEN=root
export CONSUL_HTTP_SSL_VERIFY=false

# HOME=$(pwd)
# For some stupid reason k3d won't allow "./" in the path for config files so we have to do this non-sense for the Calico config to load...

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m'

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

HELM_CHART_VER=""
# HELM_CHART_VER="--version 1.2.0-rc1"                # pinned consul-k8s chart version

if [[ "$*" == *"help"* ]]
  then
    echo -e "Syntax: ./k3d-config.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -full        Integrate with full docker compose environment. Without this, only launch Consul in k3d"
    echo "  -k8s-only    Only Install raw K3d clusters without Consul. Useful when you want to play with k8s alone"
    echo "  -update      Update K3d to the latest version"
    echo "  -eksonly     Sets 4 Kube Contexts to the appropriate names from EKSonly (https://github.com/ramramhariram/EKSonly)"
    exit 0
fi

if [[ "$*" == *"eksonly"* ]]
  then
    echo -e "${GRN}Setting Contexts from EKSonly (https://github.com/ramramhariram/EKSonly):${NC}"
    echo ""
    aws eks update-kubeconfig --region us-east-1 --name nEKS0 --alias k3d-dc3
    aws eks update-kubeconfig --region us-east-1 --name nEKS1 --alias k3d-dc3-p1
    aws eks update-kubeconfig --region us-east-1 --name nEKS2 --alias k3d-dc4
    aws eks update-kubeconfig --region us-east-1 --name nEKS3 --alias k3d-dc4-p1

    EKSONLY_TF_STATE_FILE="/home/mourne/git/EKSonly/terraform.tfstate"
    # Set this to the path of the EKSOnly repo so the outputs can be read! This MUST be set correctly!!!
fi

if [[ "$*" == *"nuke-eksonly"* ]]
  then
    echo -e "${GRN}Nuking Namespaces:${NC}"
    helm delete consul --namespace consul --kube-context $KDC3
    helm delete consul --namespace consul --kube-context $KDC3_P1
    helm delete consul --namespace consul --kube-context $KDC4
    helm delete consul --namespace consul --kube-context $KDC4_P1
    echo ""
    echo -e "${RED}It's now safe to TF destroy! ${NC}"
    echo ""
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

if [[ "$*" == *"k8s-only"* ]] || [[ "$*" == *"k3d-only"* ]]
  then
    echo -e "${RED} Building K3d clusters ONLY (-k8s-only) ${NC}"
fi

if [[ "$*" == *"eksonly"* ]]; then
    echo ""
    echo -e "${RED}Skipping k3d cluster install${NC}"
    echo ""
else

echo -e "${GRN}Consul binary version: ${NC}"
echo -e "$(which consul) ${YELL}$(consul version | grep Consul) ${NC}"
printf "${RED}"'Make sure Consul is on the latest enterprise version!!! '"${NC}\n"
echo ""

  # ==========================================
  # Is Docker running? Start docker service if not
  # ==========================================

  # service syntax to start docker differs between OSes. This checks if you're on Linux vs Mac.

  OS_NAME=$(uname -a)

  if [[ "$OS_NAME" == *"Linux"* ]]; then
      echo ""
      echo -e "${GRN}Checking that Docker is running - If not starting it. ${NC}"
      pgrep dockerd || sudo service docker start
      echo ""

      sleep 2
  else
      # Eventually put in mac syntax to start docker, its not the same as linux
      echo ""
  fi

  # Because WSL is pissing me off and the UI metrics grab from Prometheus breaks if the clock is out of sync.

  WSL=$(uname -a)

  if [[ $WSL == *"WSL"* ]]; then
    echo -e "${GRN}syncing the WSL clock to hardware...${NC}"
    sudo hwclock -s
  fi

  set +e    # If we don't do this, the script will exit when there is nothing in the hosts file

  OS_NAME=$(uname -a)

  if [[ "$OS_NAME" == *"Linux"* ]]; then
      # Match WSL2, since it handles DNS all weird like...
      echo "Linux Detected"

      HOSTS_EXISTS=$(grep "doctorconsul" /etc/hosts)

      if [[ -z "$HOSTS_EXISTS" ]]; then   # If the grep returns nothing...
        echo -e "${YELL}k3d-doctorconsul.localhost does not exist (${GRN}Adding entry${NC})"
        echo "127.0.0.1       k3d-doctorconsul.localhost" | sudo tee -a /etc/hosts > /dev/null
        grep "doctorconsul" /etc/hosts

      else
        echo -e "${YELL}k3d-doctorconsul.localhost already exists (${RED}Skipping..${NC})"
      fi

      echo ""

  elif [[ "$OS_NAME" == *"Darwin"* ]]; then
      # Match Darwin (Mac)
      echo "Mac Detected"

      HOSTS_EXISTS=$(grep "doctorconsul" /etc/hosts)

      if [[ -z "$HOSTS_EXISTS" ]]; then   # If the grep returns nothing...
        echo -e "${YELL}k3d-doctorconsul.localhost does not exist (${GRN}Adding entry${NC})"
        echo "127.0.0.1       k3d-doctorconsul.localhost" | sudo tee -a /etc/hosts > /dev/null
        grep "doctorconsul" /etc/hosts

      else
        echo -e "${YELL}k3d-doctorconsul.localhost already exists (${RED}Skipping..${NC})"
      fi

      echo ""

  else
      echo "Neither Linux nor Mac detected (${RED}Skipping..${NC}"
  fi

  # Pulling images from docker hub repeatedly, will eventually get you rate limited :(
  # This sets up a local registry so images can be pulled and cached locally.
  # This is better in the long run anyway, beecause it'll save on time and bandwidth.

  REGISTRY_EXISTS=$(k3d registry list | grep doctorconsul)

  if [[ "$REGISTRY_EXISTS" == *"doctorconsul"* ]]; then
      echo ""
      echo -e "${GRN}Checking if the k3d registry (doctorconsul) already exist${NC}"
      echo -e "${YELL}Registry exist (${RED}Skipping...${NC})"
      echo ""
  else
      k3d registry create doctorconsul.localhost --port 12345    # Creates the registry k3d-doctorconsul.localhost
  fi

  set -e    # Enabled exit on errors again.

  # Leaving these for posterity. Don't actually need to mirror the images, just cache the images locally and then import into k3d.
      # docker pull calico/cni:v3.15.0
      # docker tag calico/cni:v3.15.0 joshwolfer/calico-cni:v3.15.0
      # docker push joshwolfer/calico-cni:v3.15.0

      # docker pull calico/pod2daemon-flexvol:v3.15.0
      # docker tag calico/pod2daemon-flexvol:v3.15.0 joshwolfer/calico-pod2daemon-flexvol:v3.15.0
      # docker push joshwolfer/calico-pod2daemon-flexvol:v3.15.0

      # docker pull calico/node:v3.15.0
      # docker tag calico/node:v3.15.0 joshwolfer/calico-node:v3.15.0
      # docker push joshwolfer/calico-node:v3.15.0

  IMAGE_CALICO_CNI="calico/cni:v3.15.0"
  IMAGE_CALICO_FLEXVOL="calico/pod2daemon-flexvol:v3.15.0"
  IMAGE_CALICO_NODE="calico/node:v3.15.0"
  IMAGE_CALICO_CONTROLLER="calico/kube-controllers:v3.15.0"
  IMAGE_FAKESERVICE="nicholasjackson/fake-service:v0.25.0"

  echo -e "${GRN}Caching docker images locally${NC}"

  # Pull the public images, tag them for the k3d registry, and push them into the k3d registry
  # Probably going to have to add all the Consul images in there as well - only a matter of time before Docker Hub gets mad about those.
  # Will add them when k8s starts getting Image pull errors again ;)

  docker pull $IMAGE_CALICO_CNI
  docker tag $IMAGE_CALICO_CNI k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CNI
  docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CNI

  docker pull $IMAGE_CALICO_FLEXVOL
  docker tag $IMAGE_CALICO_FLEXVOL k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_FLEXVOL
  docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_FLEXVOL

  docker pull $IMAGE_CALICO_NODE
  docker tag $IMAGE_CALICO_NODE k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_NODE
  docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_NODE

  docker pull $IMAGE_CALICO_CONTROLLER
  docker tag $IMAGE_CALICO_CONTROLLER k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CONTROLLER
  docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CONTROLLER

  docker pull $IMAGE_FAKESERVICE
  docker tag $IMAGE_FAKESERVICE k3d-doctorconsul.localhost:12345/$IMAGE_FAKESERVICE
  docker push k3d-doctorconsul.localhost:12345/$IMAGE_FAKESERVICE


  # ==========================================
  #             Setup K3d clusters
  # ==========================================

  # echo -e "${GRN}"
  # echo -e "------------------------------------------"
  # echo -e " Download Calico Config files"
  # echo -e "------------------------------------------${NC}"

  # Fetch the Calico setup file to use with k3d.
  # K3D default CNI (flannel) doesn't work with Consul Tproxy / DNS proxy

  # curl -s https://k3d.io/v5.0.1/usage/advanced/calico.yaml -o ./kube/calico.yaml
  # ^^^ Don't downloading again. the image locations have been changed to the local k3d registry.

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
      -p "11001:8001" \
      -p "9091:9090" \
      --k3s-arg '--flannel-backend=none@server:*' \
      --registry-use k3d-doctorconsul.localhost:12345 \
      --k3s-arg="--disable=traefik@server:0"

      # -p "11000:8000"    DC3/unicorn/unicorn-frontend (fake service UI)     - Mapped to local http://127.0.0.1:11000/ui/
      # -p "11001:8001"    DC3/unicorn/unicorn-ssg-frontend (fake service UI) - Mapped to local http://127.0.0.1:11001/ui/
      # -p "9091:9090"     Prometheus UI


      # Disable flannel
      # install Calico (tproxy compatability)

  kubectl apply --context=$KDC3 -f ./kube/calico.yaml

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
      --registry-use k3d-doctorconsul.localhost:12345 \
      --k3s-arg '--flannel-backend=none@server:*'

  kubectl apply --context=$KDC3_P1 -f ./kube/calico.yaml

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
      --registry-use k3d-doctorconsul.localhost:12345 \
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
      --registry-use k3d-doctorconsul.localhost:12345 \
      --k3s-arg '--flannel-backend=none@server:*'

  kubectl apply --context=$KDC4_P1 -f ./kube/calico.yaml

fi

# ==============================================================================================================================
# ==============================================================================================================================
#
#                           Consul is actually installed into Kube clusters from HERE on
#
# ==============================================================================================================================
# ==============================================================================================================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "    Setup Consul in Kubernetes Clusters"
echo -e "==========================================${NC}"

if [[ "$*" == *"k8s-only"* ]] || [[ "$*" == *"k3d-only"* ]]
  then
    echo ""
    echo -e "${RED} K3d clusters provisioned - Aborting Consul Configs (-k8s-only) ${NC}"
    echo ""
    exit 0
fi

echo -e ""
echo -e "${GRN}Adding HashiCorp Helm Chart:${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com

echo -e ""
echo -e "${GRN}Updating Helm Repos:${NC}"
helm repo update

echo -e ""
echo -e "${YELL}Currently installed Consul Helm Version:${NC}"
helm search repo hashicorp/consul --versions --devel | head -n4

# Should probably pin a specific helm chart version, but I love living on the wild side!!!

echo -e ""
echo -e "${GRN}Writing latest Consul Helm values to disk...${NC}"
helm show values hashicorp/consul > ./kube/helm/latest-complete-helm-values.yaml

# ====================================================================================
#                      Install Consul into Kubernetes (DC3)
# ====================================================================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "   Install Consul into Kubernetes (DC3)"
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

if [[ "$*" == *"eksonly"* ]];
  then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul \
    --set server.exposeService.exposeGossipAndRPCPorts=true \
    --set tls.serverAdditionalDNSSANs=\['*.us-east-1.elb.amazonaws.com'\] \
    --debug $HELM_CHART_VER

    # On EKS we need to expose the grpc port for the consul dataplane child clusters to connect to.
    # The UI and expose services can't BOTH use a LoadBalancer service or the expose service won't pickup the UI and the child cluster can't connect.
    # Stupid complicated, not worth explaining why.
  else
    helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul \
    --set ui.enabled=true \
    --set ui.service.type=LoadBalancer \
    --set ui.service.port.http=80 \
    --debug $HELM_CHART_VER

    # On k3d, I already expose grpc 8502 as 443, which works... but was a really bad practice, because the API HTTPS address won't work now.
    # But I'm only using HTTP to access the UI / API in k3d. This isn't a great practice and I should fix this at some point.
    # I think I was just hacking things together in the beginning and didn't realize the significance of needing both 443 (real API) and 8502 grpc open. UGH.
    # I'll fix it at some point, but for now the workaround is to just add the expose servers for EKSonly.
    # I need to fix the local k3d port forwards before it'll work in k3d also.
fi

# helm upgrade consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --kube-context $KDC3 --debug
# helm list --namespace consul        # To see which chart version was actually installed. Can be an issue when using RC versions with version mismatch.

echo -e ""
echo -e "${GRN}DC3: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC}"

kubectl get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc3-credentials.yaml
kubectl get secret consul-ca-key -n consul -o yaml > ./tokens/dc3-ca-key.yaml
kubectl get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc3-partition-token.yaml

# ====================================================================================
#                Install Consul-k8s (DC3 Cernunnos Partition)
# ====================================================================================

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
echo -e "${GRN}Discover the DC3 gRPC / API external load balancer IP:${NC}"

if [[ "$*" == *"eksonly"* ]];
  then

    export DC3_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    # In EKS we have to pull the expose servers LB address for grpc and API.
    echo -e "${YELL}DC3 Consul UI, gRPC, and API External Load Balancer IP is:${NC} $DC3_LB_IP"

    echo -e "${YELL}EKSOnly state file is currently set to:${NC} $EKSONLY_TF_STATE_FILE"
    export DC3_P1_K8S_IP="$(terraform output -state=$EKSONLY_TF_STATE_FILE -json | jq -r '.endpoint.value[1]'):443"
    echo -e "${YELL}DC3-P1 K8s API address is:${NC} $DC3_P1_K8S_IP"

    # The EKSonly location MUST be specified or tf won't pull the correct variables.

    # Examples from k3d:
    # DC3 External Load Balancer IP is: 172.18.0.3
    # DC3-P1 K8s API address is: https://172.18.0.5:6443

  else
    # k3d Config:

    export DC3_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
    echo -e "${YELL}DC3 External Load Balancer IP is:${NC} $DC3_LB_IP"

    echo -e ""
    echo -e "${GRN}Discover the DC3 Cernunnos cluster Kube API${NC}"

    export DC3_P1_K8S_IP="https://$(kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"
    echo -e "${YELL}DC3-P1 K8s API address is:${NC} $DC3_P1_K8S_IP"

      # kubectl get services --selector="app=consul,component=server" --namespace consul --output jsonpath="{range .items[*]}{@.status.loadBalancer.ingress[*].ip}{end}"
      #  ^^^ Potentially better way to get list of all LB IPs, but I don't care for Doctor Consul right now.

      # kubectl config view --output "jsonpath={.clusters[?(@.name=='$KDC3_P1')].cluster.server}"
      # ^^^ Don't actually need this because the k3d kube API is exposed on via the LB on 6443 already.

fi

echo -e ""
echo -e "${GRN}DC3-P1 (Cernunnos): Helm consul-k8s install${NC}"


if [[ "$*" == *"eksonly"* ]];
  then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul $HELM_CHART_VER \
    --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC3_LB_IP \
    --set externalServers.httpsPort=8501 \
    --debug
    # Specifying both LB addresses, because if you don't, the install will fail for no connection on gRPC or API.
    # Not sure how to work around this: https://hashicorp.slack.com/archives/CPEPBFDEJ/p1690218332117449
  else
    helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul $HELM_CHART_VER \
    --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC3_LB_IP \
    --debug
    # ^^^ --dry-run to test variable interpolation... if it actually worked.

    # export DC3_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
    # export DC3_P1_K8S_IP="https://$(kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"
    # helm upgrade consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul --kube-context $KDC3_P1 --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP --set externalServers.hosts[0]=$DC3_LB_IP --debug
fi

# ====================================================================================
#                              Install Consul-k8s (DC4)
# ====================================================================================

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

if [[ "$*" == *"eksonly"* ]];
  then
    helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul \
    --set server.exposeService.exposeGossipAndRPCPorts=true \
    --set tls.serverAdditionalDNSSANs=\['*.us-east-1.elb.amazonaws.com'\] \
    --debug $HELM_CHART_VER

  else
    helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul \
    --set ui.enabled=true \
    --set ui.service.type=LoadBalancer \
    --set ui.service.port.http=80 \
    --debug $HELM_CHART_VER
fi

echo -e ""
echo -e "${GRN}DC4: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC}"

kubectl get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc4-credentials.yaml
kubectl get secret consul-ca-key -n consul -o yaml > ./tokens/dc4-ca-key.yaml
kubectl get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc4-partition-token.yaml

# ====================================================================================
#                     Install Consul-k8s (DC4 Taranis Partition)
# ====================================================================================

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

if [[ "$*" == *"eksonly"* ]];
  then

    export DC4_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    # In EKS we have to pull the expose servers LB address for grpc and API.
    echo -e "${YELL}DC4 Consul UI, gRPC, and API External Load Balancer IP is:${NC} $DC4_LB_IP"

    echo -e "${YELL}EKSOnly state file is currently set to:${NC} $EKSONLY_TF_STATE_FILE"
    export DC4_P1_K8S_IP="$(terraform output -state=$EKSONLY_TF_STATE_FILE -json | jq -r '.endpoint.value[3]'):443"
    echo -e "${YELL}DC4-P1 K8s API address is:${NC} $DC4_P1_K8S_IP"

    # The EKSonly location MUST be specified or tf won't pull the correct variables.

  else
    # k3d Config:

    export DC4_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
    echo -e "${YELL}DC4 External Load Balancer IP is:${NC} $DC4_LB_IP"

    echo -e ""
    echo -e "${GRN}Discover the DC4 Taranis cluster Kube API${NC}"

    export DC4_K8S_IP="https://$(kubectl get node k3d-dc4-p1-server-0 --context $KDC4_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"
    echo -e "${YELL}DC4 K8s API address is:${NC} $DC4_K8S_IP"

fi

echo -e ""
echo -e "${GRN}DC4-P1 (Taranis): Helm consul-k8s install${NC}"

if [[ "$*" == *"eksonly"* ]];
  then
    helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul $HELM_CHART_VER \
    --set externalServers.k8sAuthMethodHost=$DC4_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC4_LB_IP \
    --set externalServers.httpsPort=8501 \
    --debug
    # Specifying both LB addresses, because if you don't, the install will fail for no connection on gRPC or API.
    # Not sure how to work around this: https://hashicorp.slack.com/archives/CPEPBFDEJ/p1690218332117449
  else
    helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul $HELM_CHART_VER \
    --set externalServers.k8sAuthMethodHost=$DC4_K8S_IP \
    --set externalServers.hosts[0]=$DC4_LB_IP \
    --debug

fi

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

# Set new Env variables for the Consul API addresses
if [[ "$*" == *"eksonly"* ]];
  then
    DC3="http://$DC3_LB_IP:8500"
    DC4="http://$DC4_LB_IP:8500"
    echo -e "${GRN}Export ENV Variables ${NC}"
    echo "export DC3=http://$DC3_LB_IP:8500"
    echo "export DC4=http://$DC4_LB_IP:8500"
  else
    echo ""
fi



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
#            Check for -full
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

if [[ "$*" == *"-full"* ]]
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

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Unicorn Application"
echo -e "==========================================${NC}"


# ------------------------------------------
#  Modify the service yaml to pull images on EKS vs k3d local
# ------------------------------------------

if [[ "$*" == *"eksonly"* ]];
  then
    find ./kube/configs/dc3/services -type f -exec sed -i 's|image: k3d-doctorconsul\.localhost:12345/nicholasjackson/fake-service:v|image: nicholasjackson/fake-service:v|g' {} \;
    find ./kube/configs/dc4/services -type f -exec sed -i 's|image: k3d-doctorconsul\.localhost:12345/nicholasjackson/fake-service:v|image: nicholasjackson/fake-service:v|g' {} \;
    # Pull fake service from the interwebz instead of local k3d registry (which doesn't exist when using EKS)
  else
    find ./kube/configs/dc3/services -type f -exec sed -i 's|image: nicholasjackson/fake-service:v|image: k3d-doctorconsul.localhost:12345/nicholasjackson/fake-service:v|g' {} \;
    find ./kube/configs/dc4/services -type f -exec sed -i 's|image: nicholasjackson/fake-service:v|image: k3d-doctorconsul.localhost:12345/nicholasjackson/fake-service:v|g' {} \;    # Switch it back, if it's not using the local k3d registry.
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

if [[ "$*" == *"eksonly"* ]];
  then
    export UNICORN_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')
    export UNICORN_SSG_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')

    echo -e "${GRN}"
    echo -e "------------------------------------------"
    echo -e "            EKSOnly Outputs"
    echo -e "------------------------------------------${NC}"
    echo ""
    echo -e "${GRN}Consul UI Addresses: ${NC}"
    echo -e " ${YELL}DC3${NC}: http://$DC3_LB_IP:8500"
    echo -e " ${YELL}DC4${NC}: http://$DC4_LB_IP:8500"
    echo ""
    echo -e "${RED}Don't forget to login to the UI using token${NC}: 'root'"
    echo ""
    echo -e "${GRN}Fake Service UI addresses: ${NC}"
    echo -e " ${YELL}Unicorn-Frontend:${NC} $UNICORN_FRONTEND_UI_ADDR"
    echo -e " ${YELL}Unicorn-SSG-Frontend:${NC} $UNICORN_SSG_FRONTEND_UI_ADDR"
    echo ""
    echo -e "${GRN}Export ENV Variables ${NC}"
    echo " export DC3=http://$DC3_LB_IP:8500"
    echo " export DC4=http://$DC4_LB_IP:8500"
    echo ""
    echo -e "${GRN}Port forwards to map services / UI to traditional Doctor Consul local ports: ${NC}"
    echo " kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-frontend 11000:8000 > /dev/null 2>&1 &"
    echo " kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-ssg-frontend 11001:8001  > /dev/null 2>&1 &"
    echo " kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &"
    echo " kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &"
    echo ""
    printf "${RED}"'Happy Consul'\''ing!!! '"${NC}\n"
    echo ""
    echo ""
  else
    echo ""
fi



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

