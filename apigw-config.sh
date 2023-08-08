#!/bin/bash

set -e

# ====================================================================================
#                         Install Consul API Gateway (DC3)
# ====================================================================================

# Well this is awkward. You don't actually install the Consul API GW anymore. It's all handled through Kube YAML and the Gateway API.

# ====================================================================================
#                         Configuring the Gateway API Resource
# ====================================================================================

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "  Configuring the Gateway API Resources"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3 Define the Gateway config ${NC}"
kubectl apply --context $KDC3 --namespace consul -f ./kube/configs/dc3/api-gw/gateway-consul_apigw.yaml

# ------------------------------------------
#  Output the Consul APIGW LB address and ports
# ------------------------------------------

echo ""
echo -e "${GRN}DC3 Consul API Gateway LoadBalancer addresses:${NC}"

if $ARG_EKSONLY;
  then
    DC3_CONSUL_APIG_ADDR=$(kubectl get svc consul-api-gateway -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
    # This should be correct for EKS. Need to confirm.
  else
    DC3_CONSUL_APIG_ADDR=$(kubectl get svc consul-api-gateway -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
fi

echo -e " ${YELL}Consul APIG HTTP Listener:${NC} $DC3_CONSUL_APIG_ADDR:1666"
echo -e " ${YELL}Consul APIG TCP Listener:${NC} $DC3_CONSUL_APIG_ADDR:1667"

# ====================================================================================
#                            Configuring the Routes
# ====================================================================================

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         Configuring the Routes"
echo -e "------------------------------------------${NC}"

echo -e ""
echo -e "${GRN}DC3: Add HTTPRoute for Unicorn-frontend ${NC}"
kubectl apply --context $KDC3 --namespace unicorn -f ./kube/configs/dc3/api-gw/httproute-unicorn_frontend.yaml

echo ""

