#!/bin/bash

set -v

# ==========================================
#            Setup K3d cluster
# ==========================================

k3d cluster create doctorconsul --network doctorconsul_wan --api-port 127.0.0.1:6443 --k3s-arg="--disable=traefik@server:0" -p "8502:443@loadbalancer"

# ==========================================
#            Install Consul-k8s
# ==========================================

kubectl create namespace consul
kubectl create secret generic consul-gossip-encryption-key --namespace consul --from-literal=key="$(consul keygen)"
kubectl create secret generic consul-bootstrap-acl-token --namespace consul --from-literal=key="root"
kubectl create secret generic consul-license --namespace consul --from-literal=key="$(cat ./license)"

helm install consul hashicorp/consul -f ./k3d/helm-values.yaml --namespace consul --debug

# ==========================================
#              Consul configs
# ==========================================

kubectl apply -f ./k3d/configs/mgw-peering.yaml