#!/bin/bash

set -v

CONSUL_HTTP_TOKEN=root
CONSUL_HTTP_ADDR="http://127.0.0.1:8500"
DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"

# Create APs in DC1
consul partition create -name donkey -http-addr="$DC1"
consul partition create -name unicorn -http-addr="$DC1"
consul partition create -name proj1 -http-addr="$DC1"
consul partition create -name proj2 -http-addr="$DC1"

# Create APs in DC2
consul partition create -name heimdall -http-addr="$DC2"

# Create Unicorn NSs in DC1
consul namespace create -name frontend -partition=unicorn -http-addr="$DC1"
consul namespace create -name backend -partition=unicorn -http-addr="$DC1"

# Export the DC1/Donkey/default/Donkey service to DC1/default/default
consul config write ./configs/exported-services/exported-services-donkey.hcl

# ==========================================
#       Register External Services
# ==========================================

# DC1/proj1/virtual-baphomet

curl --request PUT --data @./configs/services-dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services-dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services-dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register


# ==========================================
#             ACLs / Auth N/Z
# ==========================================

# Create ACL tokens in DC1
consul acl token create \
    -node-identity=client-dc1-alpha:dc1 \
    -service-identity=joshs-obnoxiously-long-service-name-gonna-take-awhile:dc1 \
    -service-identity=josh:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000001111" \
    -http-addr="$DC1"

consul acl policy create -name dc1-read -rules @./acl/dc1-read.hcl -http-addr="$DC1"
consul acl role create -name dc1-read -policy-name dc1-read -http-addr="$DC1"
consul acl token create \
    -role-name=dc1-read \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000003333" \
    -http-addr="$DC1"

# ------------------------------------------
#          Partition proj1 RBAC
# ------------------------------------------

consul acl policy create -name team-proj1-rw -rules @./acl/team-proj1-rw.hcl -http-addr="$DC1"
consul acl role create -name team-proj1-rw -policy-name team-proj1-rw -http-addr="$DC1"
consul acl token create -partition=default -role-name=team-proj1-rw -secret="00000000-0000-0000-0000-000000002222" -http-addr="$DC1"

# ------------------------------------------
#             Consul-Admins
# ------------------------------------------

consul acl role create -name consul-admins -policy-name global-management -http-addr="$DC1"

# ==========================================
#              OIDC Auth
# ==========================================

# Enable OIDC in Consul

consul acl auth-method create -type oidc \
  -name auth0 \
  -max-token-ttl=30m \
  -config=@./auth/oidc-auth.json \
  -http-addr="$DC1"

# ------------------------------------------
# Binding rule to map Auth0 groups to Consul roles
# ------------------------------------------

# DC1/Proj1 Admins

consul acl binding-rule create \
  -method=auth0 \
  -bind-type=role \
  -bind-name=team-proj1-rw \
  -selector='proj1 in list.groups' \
  -http-addr="$DC1"

# DC1 Admins

consul acl binding-rule create \
  -method=auth0 \
  -bind-type=role \
  -bind-name=consul-admins \
  -selector='admins in list.groups' \
  -http-addr="$DC1"

# ==========================================
#                JWT Auth
# ==========================================

  # Enable JWT auth in Consul  - (Coming soon)

  # consul acl auth-method create -type jwt \
  #   -name jwt \
  #   -max-token-ttl=30m \
  #   -config=@./auth/oidc-auth.json

  # consul acl binding-rule create \
  #   -method=auth0 \
  #   -bind-type=role \
  #   -bind-name=team-proj1-rw \
  #   -selector='proj1 in list.groups'


# ==========================================
#             Cluster Peering
# ==========================================

# Set peering to use Mesh Gateways for peering control plane traffic. This must be set BEFORE peering tokens are created.

consul config write -http-addr="$DC1" ./configs/mgw/dc1-mgw.hcl
consul config write -http-addr="$DC2" ./configs/mgw/dc2-mgw.hcl

# Peer DC1/default <> DC2/default

consul peering generate-token -name DC2-default -http-addr="$DC1" > tokens/peering-dc1_default-DC2-default.token
consul peering establish -name DC1-default -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-DC2-default.token)

# Peer DC1/default <> DC2/heimdall

consul peering generate-token -name DC2-heimdall -partition="default" -http-addr="$DC1" > tokens/peering-dc1_default-DC2-heimdall.token
consul peering establish -name DC1-default -partition="heimdall" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-DC2-heimdall.token)

  # ------------------------------------------
  # Export services across Peers
  # ------------------------------------------


consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-dc1-default.hcl
consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-default.hcl



# ------------------------------------------
# Test STUFF
# ------------------------------------------



