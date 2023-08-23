#!/bin/bash

set -e

# For External services through TGW to work with service-defaults (tproxy), the following needs to happen:
#  1. service-defaults: Define external service name, address, and port
#  2. service-intention: Allow the downstream application to communicate to the upstream external service, using the service.name in the service-defaults above.
#  3. Configure terminating gateway to front the external service via TGW CRD: spec.services.name = service-name
#  4. If TGW lives in different name space, add service.write to the TGW policy. See scripts/terminating-gateway-dc4-default.sh
#
# -------- Adding services to Doctor Consul
#  Don't forget follow the instructions above ^^^. Need to modify things referenced in the terminating gateway script.

# ------------------------------------------
#          Mesh Destinations Only
# ------------------------------------------

#   This is defined in the main kube-config.sh since you can only have one per partition

# echo -e "${GRN}DC4 (default): mesh config: ${YELL}Mesh Destinations Only: True ${NC}"
# kubectl apply --context $KDC4 -f ./kube/configs/dc4/defaults/mesh.yaml


# ------------------------------------------
#          Sheol Applications
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "           Sheol Applications"
echo -e "------------------------------------------${NC}"

# --------
# Namespaces
# --------

echo ""
echo -e "${GRN}DC4 (default): Create sheol-app1 namespace:${NC} $(kubectl --context $KDC4 create namespace sheol-app1)"
echo -e "${GRN}DC4 (default): Create sheol-app2 namespace:${NC} $(kubectl --context $KDC4 create namespace sheol-app2) \n"

# --------
# service-defaults
# --------

echo -e "${GRN}DC4 (default): External Service-sheol - sheol-ext (TCP) ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/external-services/service_defaults-sheol_ext.yaml

echo -e "${GRN}DC4 (default): External Service-sheol-app1 - sheol-ext1 (TCP) ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/external-services/service_defaults-sheol_ext1.yaml

echo -e "${GRN}DC4 (default): External Service-sheol-app2 - sheol-ext2 (TCP) ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/external-services/service_defaults-sheol_ext2.yaml


# --------
# Intentions
# --------

echo -e "${GRN}DC4 (default): Service-Intention - sheol-ext  (TCP) ${NC}: $(kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4_default-sheol_ext.yaml)"
echo -e "${GRN}DC4 (default): Service-Intention - sheol-ext1 (TCP) ${NC}: $(kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4_default-sheol_ext1.yaml)"
echo -e "${GRN}DC4 (default): Service-Intention - sheol-ext2 (TCP) ${NC}: $(kubectl apply --context $KDC4 -f ./kube/configs/dc4/intentions/dc4_default-sheol_ext2.yaml)"

# ------------------------------------------
#      Sheol Fake Service Applications
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " (DC4) Sheol Applications"
echo -e "------------------------------------------${NC}"

echo ""
echo -e "${GRN}DC4 (default): Apply sheol-app serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/services/sheol_app.yaml

echo ""
echo -e "${GRN}DC4 (default): Apply sheol-app1 serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/services/sheol_app1.yaml

echo ""
echo -e "${GRN}DC4 (default): Apply sheol-app2 serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/services/sheol_app2.yaml

# kubectl delete --context $KDC4 -f ./kube/configs/dc4/services/sheol_app.yaml
# kubectl delete --context $KDC4 -f ./kube/configs/dc4/services/sheol_app1.yaml
# kubectl delete --context $KDC4 -f ./kube/configs/dc4/services/sheol_app2.yaml

# ------------------------------------------
#              Outputs
# ------------------------------------------


# # ----------------
# #   externalz tcp
# # ----------------

# echo ""
# echo -e "${GRN}DC4 Externalz-tcp UI addresses:${NC}"

# if $ARG_EKSONLY;
#   then
#     DC4_EXTERNALZ_TCP_ADDR=$(kubectl get svc externalz-tcp -nexternalz --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
#     # This should be correct for EKS. Need to confirm.
#   else
#     DC4_EXTERNALZ_TCP_ADDR=$(kubectl get svc externalz-tcp -nexternalz --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
# fi

# echo -e " ${YELL}Externalz-tcp Load balancer address:${NC} http://$DC4_EXTERNALZ_TCP_ADDR:8002/ui/"

# # ----------------
# #   externalz http
# # ----------------

# if $ARG_EKSONLY;
#   then
#     DC4_EXTERNALZ_HTTP_ADDR=$(kubectl get svc externalz-http -nexternalz --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
#     # This should be correct for EKS. Need to confirm.
#   else
#     DC4_EXTERNALZ_HTTP_ADDR=$(kubectl get svc externalz-http -nexternalz --context $KDC4 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
# fi

# echo -e " ${YELL}Externalz-tcp Load balancer address:${NC} http://$DC4_EXTERNALZ_TCP_ADDR:8003/ui/"

# ------------------------------------------
#       Terminating Gateway Stuff
# ------------------------------------------

# The TGW ACL policy has to be modifed to have permission to write services it fronts.
# This is set here: ./kube/configs/dc4/acl/terminating-gateway.hcl
# This is already good for this externalz-tcp application, but if you add additional external services, don't forget to add them to the ACL policy here.