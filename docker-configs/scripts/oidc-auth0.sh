#!/bin/bash

# ==========================================
#        OIDC Connectivity with Auth0
# ==========================================

# OIDC is setup with Auth0 and grants read to the Baphomet services in the Proj1 Admin Partition.

# ==========================================
#              OIDC Auth
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            OIDC Auth"
echo -e "==========================================${NC}"

# Enable OIDC in Consul
echo -e ""
echo -e "${GRN}Enable OIDC in Consul w/ Auth0 ${NC}"

consul acl auth-method create -type oidc \
  -name auth0 \
  -max-token-ttl=30m \
  -config=@./docker-configs/auth/oidc-auth.json \
  -http-addr="$DC1"

# ------------------------------------------
# Binding rule to map Auth0 groups to Consul roles
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "Binding rules to map Auth0 groups to Consul roles"
echo -e "------------------------------------------${NC}"

# DC1/Proj1 Admins

echo -e ""
echo -e "${GRN}DC1 team-proj1-rw${NC}"

consul acl binding-rule create \
  -method=auth0 \
  -bind-type=role \
  -bind-name=team-proj1-rw \
  -selector='proj1 in list.groups' \
  -http-addr="$DC1"

# DC1 Admins

echo -e ""
echo -e "${GRN}DC1 consul-admins${NC}"

consul acl binding-rule create \
  -method=auth0 \
  -bind-type=role \
  -bind-name=consul-admins \
  -selector='admins in list.groups' \
  -http-addr="$DC1"