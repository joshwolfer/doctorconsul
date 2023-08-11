#!/bin/bash

set -e

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
