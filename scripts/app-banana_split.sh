#!/bin/bash

# The Banana split application is for showing route splitting across multiple upstreams (local and peered)

# Banana Architecture
#    Neopolitan/banana-split/cernunnos/dc3 (downstream)
#       ice-cream(Vanilla)/banana-split/cernunnos/dc3     (34%)
#       ice-cream(Strawberry)/banana-split/cernunnos/dc3  (33%)
#       ice-cream(Chocolate)/banana-split/cernunnos/dc3   (33%)

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Banana Split Application"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Create Banana namespace${NC}"

kubectl create namespace banana-split --context $KDC3_P1

set -e

echo ""

# ------------------------------------------
#           Exported-services
# ------------------------------------------

#     We'll need exports for upstreams that live in the other clusters.
#     These need to be added the previously configured exported services files (because 1 per partition)

# ==========================================
#                Services
# ==========================================

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "    Launch Consul Service Configs"
echo -e "------------------------------------------${NC}"

# ----------------
# neopolitan (downstream)
# ----------------

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Apply Neopolitan (downstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-neopolitan.yaml

# ----------------
# Upstreams
# ----------------

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Apply Ice Cream (Vanilla)  (upstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_vanilla.yaml

echo -e ""
echo -e "${GRN}DC4 (Cernunnos): Apply Ice Cream (Strawberry) (upstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_strawberry.yaml

echo -e ""
echo -e "${GRN}DC4 (Cernunnos): Apply Ice Cream (Chocolate) (upstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_chocolate.yaml


# ------------------------------------------
#                 Intentions
# ------------------------------------------

# echo -e "${GRN}"
# echo -e "------------------------------------------"
# echo -e "              Intentions"
# echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Intention for DC3/cernunnos/banana-split/ice-cream ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-banana_split-ice_cream.yaml

echo -e ""

# ------------------------------------------
#                 Service Resolver + Splitter
# ------------------------------------------

echo -e "${GRN}DC3 (default): Apply service-splitter: ice-cream ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/service-splitter/service-splitter-ice_cream.yaml

echo -e "${GRN}DC3 (default): Apply service-resolver: ice-cream ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/service-resolver/service-resolver-ice_cream.yaml


# Delete command:

# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-neopolitan.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_vanilla.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_strawberry.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/services/banana_split-icecream_chocolate.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-banana_split-ice_cream.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/service-splitter/service-splitter-ice_cream.yaml
# kubectl delete --context $KDC3_P1 -f ./kube/configs/dc3/service-resolver/service-resolver-ice_cream.yaml
