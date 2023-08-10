#!/bin/bash

set -e

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
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_https-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_https-allow.yaml

echo -e "${GRN}DC3 (default): Service Intention - External Service - what is my ip IP ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-whatismyip-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-whatismyip-allow.yaml

# ------------------------------------------
#       Externalz-Alpha application
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " (DC3) Externalz-Alpha App"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): Apply Externalz-Alpha serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/externalz-alpha.yaml

# Add intention -!!!

# This Application is intented to connect to external services
# Future: Setup Lambda FakeService

echo ""
echo -e "${GRN}DC3 Externalz-Alpha UI addresses:${NC}"

if $ARG_EKSONLY;
  then
    DC3_EXTERNALZ_ALPHA_ADDR=$(kubectl get svc externalz-alpha -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
    # This should be correct for EKS. Need to confirm.
  else
    DC3_EXTERNALZ_ALPHA_ADDR=$(kubectl get svc externalz-alpha -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
fi

echo -e " ${YELL}Externalz-Alpha Load balancer address:${NC} http://$DC3_EXTERNALZ_ALPHA_ADDR:8001/ui/"

echo -e "${GRN}DC3 (default): mesh config: ${YELL}Mesh Destinations Only: True ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/defaults/mesh.yaml

# ------------------------------------------
#       Terminating Gateway Stuff
# ------------------------------------------

# The TGW ACL policy has to be modifed to have permission to write services it fronts.
# This is set here: ./kube/configs/dc3/acl/terminating-gateway.hcl
# This is already good for this externalz-alpha application, but if you add additional external services, don't forget to add them to the ACL policy here.