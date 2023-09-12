#!/bin/bash

set -e

# For External services through TGW to work with service-defaults (tproxy), the following needs to happen:
#  1. service-defaults: Define external service name, address, and port
#  2. service-intention: Allow the downstream application to communicate to the upstream external service, using the service.name in the service-defaults above.
#  3. Configure terminating gateway to front the external service via TGW CRD: spec.services.name = service-name
#  4. If TGW lives in different name space, add service.write to the TGW policy. See scripts/terminating-gateway-dc3-default.sh
#
# -------- Adding services to Doctor Consul
#  Don't forget follow the instructions above ^^^. Need to modify things referenced in the terminating gateway script.

# ------------------------------------------
#          Mesh Destinations Only
# ------------------------------------------

#   This is defined in the main kube-config.sh since you can only have one per partition

# echo -e "${GRN}DC3 (default): mesh config: ${YELL}Mesh Destinations Only: True ${NC}"
# kubectl apply --context $KDC3 -f ./kube/configs/dc3/defaults/mesh.yaml


# ------------------------------------------
#          Externals Application
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "           Externals Application"
echo -e "------------------------------------------${NC}"

# --------
# Namespace
# --------

echo -e ""
echo -e "${GRN}DC3 (default): Create externalz namespace${NC}"
kubectl --context $KDC3 create namespace externalz

# --------
# service-defaults
# --------

echo -e "${GRN}DC3 (default): External Service-default - Example.com (TCP) ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com_tcp.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com.yaml

    # protocol: tcp
    # destination:
    #   addresses:
    #     - "example.com"
    #     - "www.wolfmansound.com"
    #   port: 443

echo -e "${GRN}DC3 (default): External Service-default - Example.com (HTTP) ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com_http.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-example.com_http.yaml

    # protocol: http
    # destination:
    #   addresses:
    #     - "example.com"
    #     - "www.wolfmansound.com"
    #   port: 80


echo -e "${GRN}DC3 (default): External Service-defaults - whatismyip  ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-whatismyip.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/external-services/service-defaults-whatismyip.yaml


# --------
# Intentions
# --------

echo -e "${GRN}DC3 (default): Service Intention - External Service - Example.com (TCP) ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_tcp-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_tcp-allow.yaml

echo -e "${GRN}DC3 (default): Service Intention - External Service - Example.com (HTTP) ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_http-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-example_http-allow.yaml

echo -e "${GRN}DC3 (default): Service Intention - External Service - what is my ip IP ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-whatismyip-allow.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/intentions/dc3-default-external-whatismyip-allow.yaml

# ------------------------------------------
#       Externalz-tcp application
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " (DC3) Externalz-tcp App"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): Apply Externalz-tcp serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/externalz-tcp.yaml

# This Application is intented to connect to external services
# Future: Setup Lambda FakeService

# ------------------------------------------
#       Externalz-http application
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e " (DC3) Externalz-http App"
echo -e "------------------------------------------${NC}"

echo -e "${GRN}DC3 (default): Apply Externalz-http serviceAccount, serviceDefaults, service, deployment ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/services/externalz-http.yaml

# ------------------------------------------
#              Outputs
# ------------------------------------------


# ----------------
#   externalz tcp
# ----------------

echo ""
echo -e "${GRN}DC3 Externalz-tcp UI addresses:${NC}"

if $ARG_EKSONLY;
  then
    DC3_EXTERNALZ_TCP_ADDR=$(kubectl get svc externalz-tcp -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
    # This should be correct for EKS. Need to confirm.
  else
    DC3_EXTERNALZ_TCP_ADDR=$(kubectl get svc externalz-tcp -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
fi

echo -e " ${YELL}Externalz-tcp Load balancer address:${NC} http://$DC3_EXTERNALZ_TCP_ADDR:8002/ui/"

# ----------------
#   externalz http
# ----------------

if $ARG_EKSONLY;
  then
    DC3_EXTERNALZ_HTTP_ADDR=$(kubectl get svc externalz-http -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
    # This should be correct for EKS. Need to confirm.
  else
    DC3_EXTERNALZ_HTTP_ADDR=$(kubectl get svc externalz-http -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
fi

echo -e " ${YELL}Externalz-http Load balancer address:${NC} http://$DC3_EXTERNALZ_HTTP_ADDR:8003/ui/"

# ------------------------------------------
#       Terminating Gateway Stuff
# ------------------------------------------

# The TGW ACL policy has to be modifed to have permission to write services it fronts.
# This is set here: ./kube/configs/dc3/acl/terminating-gateway.hcl
# This is already good for this externalz-tcp application, but if you add additional external services, don't forget to add them to the ACL policy here.