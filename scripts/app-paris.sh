#!/bin/bash

echo -e "${GRN}"
echo -e "=========================================="
echo -e "        Install Paris Application"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}DC3 (cernunnos): Create unicorn namespace${NC}"

kubectl create namespace paris --context $KDC3_P1

set -e

echo ""
echo "Permissive mode requires a Mesh config to exist that permits Permissive mode at a global level."
echo "Config previously configured prior to this script: kube/configs/dc3/defaults/mesh-dc3_cernunnos.yaml"
echo ""

# ------------------------------------------
#           Exported-services
# ------------------------------------------

# echo -e "${GRN}"
# echo -e "------------------------------------------"
# echo -e "           Exported Services"
# echo -e "------------------------------------------${NC}"

# Shouldn't need any exports on this service.

# ==========================================
#                Services
# ==========================================

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "    Launch Consul Service Configs"
echo -e "------------------------------------------${NC}"

# ----------------
# Paris (permissive upstream)
# ----------------

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Apply Paris (upstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/paris-paris-cernunnos.yaml

# ----------------
# Downstreams
# ----------------

# Need two frontends:
#   • One that goes direct - no Mesh (Permissive mode)
#   • One that goes via the mesh

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Apply Pretty-Please (downstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/paris-pretty_please.yaml

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Apply Leroy-Jenkins (downstream) serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/services/paris-leroy_jenkins.yaml


# ------------------------------------------
#                 Intentions
# ------------------------------------------

# echo -e "${GRN}"
# echo -e "------------------------------------------"
# echo -e "              Intentions"
# echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 (Cernunnos): Intention for DC3/cernunnos/paris/paris ${NC}"
kubectl apply --context $KDC3_P1 -f ./kube/configs/dc3/intentions/dc3-cernunnos-paris-paris.yaml

echo -e ""
