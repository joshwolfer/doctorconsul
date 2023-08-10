#!/bin/bash

set -e

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

# ==========================================
#                Services
# ==========================================

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