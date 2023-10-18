#!/bin/bash

# ==========================================
#       Register External Services
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "    Register External Baphomet Services"
echo -e "==========================================${NC}"

echo -e "${GRN}DC1/proj1/virtual-baphomet ${NC}"

echo ""
echo -e "${GRN}DC1/Proj1/default/baphomet0:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"
echo -e "${GRN}DC1/Proj1/default/baphomet1:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"
echo -e "${GRN}DC1/Proj1/default/baphomet2:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"

# ------------------------------------------
#          Partition proj1 RBAC
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         Partition proj1 RBAC"
echo -e "------------------------------------------${NC}"
echo -e ""

echo -e "${GRN}ACL Policy+Role: DC1/proj1/team-proj1-rw${NC}"
consul acl policy create -name team-proj1-rw -rules @./docker-configs/acl/team-proj1-rw.hcl -http-addr="$DC1"
consul acl role create -name team-proj1-rw -policy-name team-proj1-rw -http-addr="$DC1"
echo -e ""
echo -e "${GRN}ACL Token: 000000002222${NC}"
consul acl token create \
    -partition=default \
    -role-name=team-proj1-rw \
    -secret="00000000-0000-0000-0000-000000002222" \
    -accessor="00000000-0000-0000-0000-000000002222" \
    -http-addr="$DC1"

