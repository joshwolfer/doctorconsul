#!/bin/bash

set -e

# ------------------------------------------
#        Terminating Gateway Info
# ------------------------------------------

# Terminating gateway are rather tricky with ACLs enabled. To add external services to a TGW a few things need to happen:
#     1. The TGW ACL role needs to be updated to include service:write for EVERY service it will be fronting.
#     2. If the TGW exists in a non-default namespace, the token will have to be scoped into the default namespace (yeah... fun times)
#         (NMD): How exactly do we do this easily? Or at all...
#         Example: The DC4 sheol TGW below.
#     3. Service-defaults or standard service registration needs to be used to register the external services
#     4. The TGW config needs to reference each service it is fronting
#     5. A service-intention is needed to allow the downstream service to the upstream external service.

# ------------------------------------------
#           DC3 Terminating Gateway
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         DC3  Terminating Gateway"
echo -e "------------------------------------------${NC}"

# Add the terminating-gateway ACL policy to the TGW Role, so it can actually service:write the services it fronts. DUMB.
consul acl policy create -name "Terminating-Gateway-Service-Write" -rules @./kube/configs/dc3/acl/dc3_default-terminating-gateway.hcl -http-addr="$DC3"
export DC3_TGW_ROLEID=$(consul acl role list -http-addr="$DC3" -format=json | jq -r '.[] | select(.Name == "consul-terminating-gateway-acl-role") | .ID')
consul acl role update -id $DC3_TGW_ROLEID -policy-name "Terminating-Gateway-Service-Write" -http-addr="$DC3"

echo -e "${GRN}DC3 (default): Terminating-Gateway config   ${NC}"
kubectl apply --context $KDC3 -f ./kube/configs/dc3/tgw/dc3_default-tgw.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc3/tgw/dc3_default-tgw.yaml


# ------------------------------------------
#           DC4 Terminating Gateway
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         DC4  Terminating Gateway"
echo -e "------------------------------------------${NC}"

# Add the terminating-gateway ACL policy to the TGW Role, so it can actually service:write the services it fronts. DUMB.
consul acl policy create -name "Terminating-Gateway-Service-Write" -rules @./kube/configs/dc4/acl/dc4_sheol-terminating-gateway.hcl -http-addr="$DC4"
export DC4_TGW_ROLEID=$(consul acl role list -http-addr="$DC4" -format=json | jq -r '.[] | select(.Name == "consul-sheol-tgw-acl-role") | .ID')
consul acl role update -id $DC4_TGW_ROLEID -policy-name "Terminating-Gateway-Service-Write" -http-addr="$DC4"

echo -e "${GRN}DC4 (default): Terminating-Gateway config   ${NC}"
kubectl apply --context $KDC4 -f ./kube/configs/dc4/tgw/dc4_sheol-tgw.yaml
# kubectl delete --context $KDC3 -f ./kube/configs/dc4/tgw/dc4_sheol-tgw.yaml


# curl 'http://af321be31a9474e3a919914b9567f910-1542581749.us-east-1.elb.amazonaws.com:8500/v1/catalog/gateway-services/sheol-tgw?token=root&ns=sheol'
# API to see what's attached to a TGW