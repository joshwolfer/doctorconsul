#!/bin/bash

set -e

echo -e "${RED}EKS only Argument is:${NC} $ARG_EKSONLY"
echo ""

mkdir -p ./logs/     # Create logs dir if it doesn't exist.

echo -e "${GRN}"
echo -e "=========================================="
echo -e "    Setup Consul in Kubernetes Clusters"
echo -e "==========================================${NC}"

if $ARG_K8S_ONLY;
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

# ==========================================
# ==========================================
#  Define Functions to run each HELM install in parallel (when possible)
# ==========================================
# ==========================================

InstallConsulDC3 () {

  # ====================================================================================
  #                      Install Consul into Kubernetes (DC3)
  # ====================================================================================

  if $ARG_DEBUG;
    then
      DEBUG="--debug"
  fi

  echo -e ""
  echo -e "${GRN}DC3: Create Consul namespace:${NC} $(kubectl --context $KDC3 create namespace consul) \n"
  echo -e "${GRN}DC3: Create secrets for gossip, ACL token, Consul License:${NC} \
  \n$(kubectl --context $KDC3 create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)") \
  \n$(kubectl --context $KDC3 create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root") \
  \n$(kubectl --context $KDC3 create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)") \n"

  # ------------------------------------------
  #                Helm install
  # ------------------------------------------

  echo -e "${GRN}DC3: Helm consul-k8s install Started...${NC}\n${RED}DC3 install log:${NC} tail -f ./logs/dc3-helm-install.log\n"

  if $ARG_EKSONLY; then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --kube-context $KDC3 $DEBUG \
    --set server.exposeService.exposeGossipAndRPCPorts=true \
    --set tls.serverAdditionalDNSSANs=\['*.elb.amazonaws.com'\] $HELM_CHART_VER # > ./logs/dc3-helm-install.log 2>&1

    # Because Macs are evidently dumb and can't handle stdout redirection AND multi-line bash... Cause who needs install logs anyway?
    #   The solution to this is far more complicated than I care to implement. If I were to do it, I could do a wrapper function.
    #   Basically execute the helm install via function(original args, file_path) and have it do OS detection.
    #   Something like this would probably work. but seriously, unless I'm bored, I'm just not going to worry about this.

        # function run_command() {
        # local original_command="$1"
        # local filepath="$2"

        # # Assuming OS_NAME is defined elsewhere

        # if [ "$OS_NAME" == "Linux" ]; then
        #     # Execute the original command and redirect STDOUT to filepath
        #     eval "$original_command > $filepath"
        # elif [ "$OS_NAME" == "Darwin" ]; then
        #     # Execute the original command without redirecting
        #     eval "$original_command"
        # else
        #     echo "Unsupported OS_NAME: $OS_NAME"
        # fi
        # }

    # Opening up the SANs to cover any AWS region.

    # On EKS we need to expose the grpc port for the consul dataplane child clusters to connect to.
    # The UI and expose services can't BOTH use a LoadBalancer service or the expose service won't pickup the UI and the child cluster can't connect.
    # Stupid complicated, not worth explaining why.

  elif $ARG_GKE; then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --kube-context $KDC3 $DEBUG \
    --set server.exposeService.exposeGossipAndRPCPorts=true \
    --set tls.serverAdditionalDNSSANs=\['*.some-gke-address.com'\] \
    --set connectInject.apiGateway.manageExternalCRDs=false \
    $HELM_CHART_VER > ./logs/dc3-helm-install.log 2>&1

  else   # k3d local
    helm install consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --kube-context $KDC3 $DEBUG \
    --set ui.enabled=true \
    --set ui.service.type=LoadBalancer \
    --set ui.service.port.http=80 $HELM_CHART_VER # > ./logs/dc3-helm-install.log 2>&1

    # On k3d, I already expose grpc 8502 as 443, which works... but was a really bad practice, because the API HTTPS address won't work now.
    # But I'm only using HTTP to access the UI / API in k3d. This isn't a great practice and I should fix this at some point.
    # I think I was just hacking things together in the beginning and didn't realize the significance of needing both 443 (real API) and 8502 grpc open. UGH.
    # I'll fix it at some point, but for now the workaround is to just add the expose servers for EKSonly.
    # I need to fix the local k3d port forwards before it'll work in k3d also.
  fi

  # helm list --namespace consul        # To see which chart version was actually installed. Can be an issue when using RC versions with version mismatch.

  echo -e "${GRN}DC3: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC} \n"
  kubectl --context $KDC3 get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc3-credentials.yaml
  kubectl --context $KDC3 get secret consul-ca-key -n consul -o yaml > ./tokens/dc3-ca-key.yaml
  kubectl --context $KDC3 get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc3-partition-token.yaml

}

InstallConsulDC3_P1 () {

  # ====================================================================================
  #                Install Consul-k8s (DC3 Cernunnos Partition)
  # ====================================================================================

  if $ARG_DEBUG;
    then
      DEBUG="--debug"
  fi

  echo -e "${RED}EKS only Argument in dc3_p1 is:${NC} $ARG_EKSONLY"
  echo ""

  echo -e "${GRN}DC3-P1: Create Consul namespace:${NC} $(kubectl --context $KDC3_P1 create namespace consul) \n"

  echo -e ""
  echo -e "${GRN}DC3-P1 (Cernunnos): Install Kube secrets (CA cert / key, bootstrap token, partition token) extracted from DC3:${NC} \
  \n$(kubectl --context $KDC3_P1 apply -f ./tokens/dc3-credentials.yaml) \
  \n$(kubectl --context $KDC3_P1 apply -f ./tokens/dc3-ca-key.yaml) \
  \n$(kubectl --context $KDC3_P1 apply -f ./tokens/dc3-partition-token.yaml)"
  # ^^^ Consul namespace is already embedded in the secret yaml.

  echo -e "${GRN}DC3-P1 (Cernunnos): Create secret Consul License:${NC} $(kubectl --context $KDC3_P1 create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)") \n"

  # ------------------------------------------
  # Discover Details needed for the helm install
  # ------------------------------------------

  if $ARG_EKSONLY; then
    export DC3_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    export DC3_P1_K8S_IP="$(terraform output -state=$EKSONLY_TF_STATE_FILE -json | jq -r '.endpoint.value[1]'):443"

    echo -e "${YELL}EKSOnly state file is currently set to:${NC} $EKSONLY_TF_STATE_FILE"

  elif $ARG_GKE; then
    export DC3_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    export DC3_P1_K8S_IP="Need to DISCOVER the K8S API for GKE!"
    # Need to DISCOVER the K8S API for GKE!

  else  # k3d Config:
    export DC3_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
    export DC3_P1_K8S_IP="https://$(kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"

      # kubectl get services --selector="app=consul,component=server" --namespace consul --output jsonpath="{range .items[*]}{@.status.loadBalancer.ingress[*].ip}{end}"
      #  ^^^ Potentially better way to get list of all LB IPs, but I don't care for Doctor Consul right now.

      # kubectl config view --output "jsonpath={.clusters[?(@.name=='$KDC3_P1')].cluster.server}"
      # ^^^ Don't actually need this because the k3d kube API is exposed on via the LB on 6443 already.
  fi

  # Examples from k3d:
  #   DC3 External Load Balancer IP is: 172.18.0.3
  #   DC3-P1 K8s API address is: https://172.18.0.5:6443

  echo -e "${GRN}Discover the DC3 external load balancer IP:${NC}"
  echo -e "${YELL}DC3 Consul UI, gRPC, and API External Load Balancer IP is:${NC} $DC3_LB_IP"

  echo -e "${GRN}Discover the DC3 Cernunnos cluster Kube API${NC}"
  echo -e "${YELL}DC3-P1 K8s API address is:${NC} $DC3_P1_K8S_IP"

  echo "$DC3_LB_IP" > ./tokens/dc3_lb_ip.txt
  echo "$DC3_P1_K8S_IP" > ./tokens/dc3_p1_k8s_ip.txt
  # These token files are so we can pass the address to the parent script, since this is called as a BG process, you can't pass variables back.

  # ------------------------------------------
  #                Helm install
  # ------------------------------------------

  echo -e ""
  echo -e "${GRN}DC3-P1 (Cernunnos): Helm consul-k8s install Started...${NC} \n${RED}DC3-P1 install log:${NC} tail -f ./logs/dc3_p1-helm-install.log\n"

  if $ARG_EKSONLY; then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul --kube-context $KDC3_P1 $HELM_CHART_VER $DEBUG \
    --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC3_LB_IP \
    --set externalServers.httpsPort=8501 # > ./logs/dc3_p1-helm-install.log 2>&1
    # Specifying both LB addresses, because if you don't, the install will fail for no connection on gRPC or API.
    # Not sure how to work around this: https://hashicorp.slack.com/archives/CPEPBFDEJ/p1690218332117449

  elif $ARG_GKE; then
    helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul --kube-context $KDC3_P1 $HELM_CHART_VER $DEBUG \
    --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC3_LB_IP \
    --set externalServers.httpsPort=8501 > ./logs/dc3_p1-helm-install.log 2>&1

  else
    helm install consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul --kube-context $KDC3_P1 $HELM_CHART_VER $DEBUG \
    --set externalServers.k8sAuthMethodHost=$DC3_P1_K8S_IP \
    --set externalServers.hosts[0]=$DC3_LB_IP # > ./logs/dc3_p1-helm-install.log 2>&1
    # ^^^ --dry-run to test variable interpolation... if it actually worked.

  fi
}

InstallConsulDC4 () {
  # ====================================================================================
  #                              Install Consul-k8s (DC4)
  # ====================================================================================

  if $ARG_DEBUG;
    then
      DEBUG="--debug"
  fi

  echo -e "${GRN}DC4: Create Consul namespace:${NC} $(kubectl --context $KDC4 create namespace consul) \n"
  echo -e "${GRN}DC4: Create sheol namespace:${NC} $(kubectl --context $KDC4 create namespace sheol) \n"

  echo -e "${GRN}DC4: Create secrets for gossip, ACL token, Consul License:${NC} \
  \n$(kubectl --context $KDC4 create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)") \
  \n$(kubectl --context $KDC4 create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root") \
  \n$(kubectl --context $KDC4 create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)") \n"

  # ------------------------------------------
  #                Helm install
  # ------------------------------------------

  echo -e "${GRN}DC4: Helm consul-k8s install Started...${NC} \n${RED}DC4 install log:${NC} tail -f ./logs/dc4-helm-install.log\n"

  if $ARG_EKSONLY; then
      helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul --kube-context $KDC4 $DEBUG \
      --set server.exposeService.exposeGossipAndRPCPorts=true \
      --set tls.serverAdditionalDNSSANs=\['*.elb.amazonaws.com'\] $HELM_CHART_VER # > ./logs/dc4-helm-install.log 2>&1

  elif $ARG_GKE; then
      helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul --kube-context $KDC4 $DEBUG \
      --set server.exposeService.exposeGossipAndRPCPorts=true \
      --set tls.serverAdditionalDNSSANs=\['*.some-gke-address.com'\] \
      --set connectInject.apiGateway.manageExternalCRDs=false \
      $HELM_CHART_VER # > ./logs/dc4-helm-install.log 2>&1
          # Figure out what the GKE SANs should be


  else    #k3d
      helm install consul hashicorp/consul -f ./kube/helm/dc4-helm-values.yaml --namespace consul --kube-context $KDC4 $DEBUG \
      --set ui.enabled=true \
      --set ui.service.type=LoadBalancer \
      --set ui.service.port.http=80 $HELM_CHART_VER # > ./logs/dc4-helm-install.log 2>&1
  fi

  echo -e "${GRN}DC4: Extract CA cert / key, bootstrap token, and partition token for child Consul Dataplane clusters ${NC} \n"

  kubectl --context $KDC4 get secret consul-ca-cert consul-bootstrap-acl-token -n consul -o yaml > ./tokens/dc4-credentials.yaml
  kubectl --context $KDC4 get secret consul-ca-key -n consul -o yaml > ./tokens/dc4-ca-key.yaml
  kubectl --context $KDC4 get secret consul-partitions-acl-token -n consul -o yaml > ./tokens/dc4-partition-token.yaml
}

InstallConsulDC4_P1 () {
  # ====================================================================================
  #                     Install Consul-k8s (DC4 Taranis Partition)
  # ====================================================================================

  if $ARG_DEBUG;
    then
      DEBUG="--debug"
  fi

  echo -e "${RED}EKS only Argument in dc4_p1 is:${NC} $ARG_EKSONLY"
  echo ""

  echo -e "${GRN}DC4-P1 (Taranis): Create Consul namespace:${NC} $(kubectl --context $KDC4_P1 create namespace consul) \n"

  echo -e "${GRN}DC4-P1 (Taranis): Install Kube secrets (CA cert / key, bootstrap token, partition token) extracted from DC4:${NC} \
  \n$(kubectl --context $KDC4_P1 apply -f ./tokens/dc4-credentials.yaml) \
  \n$(kubectl --context $KDC4_P1 apply -f ./tokens/dc4-ca-key.yaml) \
  \n$(kubectl --context $KDC4_P1 apply -f ./tokens/dc4-partition-token.yaml) \n"
  # ^^^ Consul namespace is already embedded in the secret yaml.

  echo -e "${GRN}DC4-P1 (Taranis): Create secret Consul License:${NC} $(kubectl --context $KDC4_P1 create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)") \n"

  # ------------------------------------------
  # Discover Details needed for the helm install
  # ------------------------------------------

  if $ARG_EKSONLY; then
    export DC4_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    export DC4_P1_K8S_IP="$(terraform output -state=$EKSONLY_TF_STATE_FILE -json | jq -r '.endpoint.value[3]'):443"

    echo -e "${YELL}EKSOnly state file is currently set to:${NC} $EKSONLY_TF_STATE_FILE"

  elif $ARG_GKE; then
    export DC4_LB_IP="$(kubectl get svc consul-expose-servers -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
    export DC4_P1_K8S_IP="FIGURE THIS OUT!"
    # Need to DISCOVER the K8S API for GKE!

  else    # k3d Config
      export DC4_LB_IP="$(kubectl get svc consul-ui -nconsul --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
      export DC4_P1_K8S_IP="https://$(kubectl get node k3d-dc4-p1-server-0 --context $KDC4_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'):6443"

  fi

  echo -e "${GRN}Discover the DC4 external load balancer IP:${NC} \n"
  echo -e "${YELL}DC4 Consul UI, gRPC, and API External Load Balancer IP is:${NC} $DC4_LB_IP"

  echo -e "${GRN}Discover the DC4 Taranis cluster Kube API${NC}"
  echo -e "${YELL}DC4-P1 K8s API address is:${NC} $DC4_P1_K8S_IP"

  echo "$DC4_LB_IP" > ./tokens/dc4_lb_ip.txt
  echo "$DC4_P1_K8S_IP" > ./tokens/dc4_p1_k8s_ip.txt

  # ------------------------------------------
  #                Helm install
  # ------------------------------------------

  echo ""
  echo -e "${GRN}DC4-P1 (Taranis): Helm consul-k8s install Started...${NC} \n${RED}DC4-P1 install log:${NC} tail -f ./logs/dc4_p1-helm-install.log\n"

  if $ARG_EKSONLY; then
      helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul --kube-context $KDC4_P1 $HELM_CHART_VER $DEBUG \
      --set externalServers.k8sAuthMethodHost=$DC4_P1_K8S_IP \
      --set externalServers.hosts[0]=$DC4_LB_IP \
      --set externalServers.httpsPort=8501 # > ./logs/dc4_p1-helm-install.log 2>&1
      # Specifying both LB addresses, because if you don't, the install will fail for no connection on gRPC or API.
      # Not sure how to work around this: https://hashicorp.slack.com/archives/CPEPBFDEJ/p1690218332117449

  elif $ARG_GKE; then
      helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul --kube-context $KDC4_P1 $HELM_CHART_VER $DEBUG \
      --set externalServers.k8sAuthMethodHost=$DC4_P1_K8S_IP \
      --set externalServers.hosts[0]=$DC4_LB_IP \
      --set externalServers.httpsPort=8501 # > ./logs/dc4_p1-helm-install.log 2>&1

  else
      helm install consul hashicorp/consul -f ./kube/helm/dc4-p1-helm-values.yaml --namespace consul --kube-context $KDC4_P1 $HELM_CHART_VER $DEBUG \
      --set externalServers.k8sAuthMethodHost=$DC4_P1_K8S_IP \
      --set externalServers.hosts[0]=$DC4_LB_IP # > ./logs/dc4_p1-helm-install.log 2>&1
  fi
}

# ==========================================
# ==========================================
#        HELM install in parallel
# ==========================================
# ==========================================

pids=()  # array to hold background job pids

InstallConsulDC3 "$@" &
pids+=($!)

InstallConsulDC4 "$@" &
pids+=($!)

for pid in ${pids[*]}; do    # This waits for the DC3 and DC4 helm installs. Need to wait for these, because DC3_P1 and DC4_P1 are dependent on DC3/DC4 consul api addresses.
    wait $pid
done

if $ARG_GKE;     # ------------------------------------------ Temporary break point while I figure out how to get consul k8s in GKE working.
  then
    exit 0
fi

# Now that DC3 and DC4 were built in parallel, install Consul to the child partitions
InstallConsulDC3_P1 "$@" &
pids+=($!)

InstallConsulDC4_P1 "$@" &
pids+=($!)

for pid in ${pids[*]}; do
    wait $pid
done