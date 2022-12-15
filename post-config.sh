#!/bin/bash

set -v

# export the variable to be used by the commands below
export CONSUL_HTTP_TOKEN=root

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"

mkdir -p ./tokens

# Block traffic from consul-server1-dc1 to consul-server1-dc2
docker exec -i -t consul-server1-dc1 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.4 -j DROP"

# Block traffic from consul-server1-dc2 to consul-server-dc1
docker exec -i -t consul-server1-dc2 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.2 -j DROP"

# ^^^ This is to insure that cluster peering is indeed working over mesh gateways.


# Wait for both DCs to electer a leader before starting resource provisioning
until curl -s -k ${DC1}/v1/status/leader | grep 8300; do
  echo "Waiting for DC1 Consul to start"
  sleep 1
done

until curl -s -k ${DC2}/v1/status/leader | grep 8300; do
  echo "Waiting for DC2 Consul to start"
  sleep 1
done

# ==========================================
#            Admin Partitions
# ==========================================

# Create APs in DC1
consul partition create -name donkey -http-addr="$DC1"
consul partition create -name unicorn -http-addr="$DC1"
consul partition create -name proj1 -http-addr="$DC1"
consul partition create -name proj2 -http-addr="$DC1"

# Create APs in DC2
consul partition create -name unicorn -http-addr="$DC2"
consul partition create -name heimdall -http-addr="$DC2"
consul partition create -name chunky -http-addr="$DC2"

# ==========================================
#                Namespaces
# ==========================================

# Create Unicorn NSs in DC1
consul namespace create -name frontend -partition=unicorn -http-addr="$DC1"
consul namespace create -name backend -partition=unicorn -http-addr="$DC1"

# Create Unicorn NSs in DC2
consul namespace create -name frontend -partition=unicorn -http-addr="$DC2"
consul namespace create -name backend -partition=unicorn -http-addr="$DC2"

# # ==========================================
# #       Register External Services
# # ==========================================

# # DC1/proj1/virtual-baphomet

# curl --request PUT --data @./configs/services-dc1-proj1-baphomet0.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"
# curl --request PUT --data @./configs/services-dc1-proj1-baphomet1.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"
# curl --request PUT --data @./configs/services-dc1-proj1-baphomet2.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"

# # ==========================================
# #             ACLs / Auth N/Z
# # ==========================================

# # Create ACL tokens in DC1
# consul acl token create \
#     -node-identity=client-dc1-alpha:dc1 \
#     -service-identity=joshs-obnoxiously-long-service-name-gonna-take-awhile:dc1 \
#     -service-identity=josh:dc1 \
#     -partition=default \
#     -namespace=default \
#     -secret="00000000-0000-0000-0000-000000001111" \
#     -http-addr="$DC1"

# consul acl policy create -name dc1-read -rules @./acl/dc1-read.hcl -http-addr="$DC1"
# consul acl role create -name dc1-read -policy-name dc1-read -http-addr="$DC1"
# consul acl token create \
#     -role-name=dc1-read \
#     -partition=default \
#     -namespace=default \
#     -secret="00000000-0000-0000-0000-000000003333" \
#     -http-addr="$DC1"

# # ------------------------------------------
# #          Partition proj1 RBAC
# # ------------------------------------------

# consul acl policy create -name team-proj1-rw -rules @./acl/team-proj1-rw.hcl -http-addr="$DC1"
# consul acl role create -name team-proj1-rw -policy-name team-proj1-rw -http-addr="$DC1"
# consul acl token create -partition=default -role-name=team-proj1-rw -secret="00000000-0000-0000-0000-000000002222" -http-addr="$DC1"

# # ------------------------------------------
# #             Consul-Admins
# # ------------------------------------------

# consul acl role create -name consul-admins -policy-name global-management -http-addr="$DC1"

# # ==========================================
# #              OIDC Auth
# # ==========================================

# # Enable OIDC in Consul

# consul acl auth-method create -type oidc \
#   -name auth0 \
#   -max-token-ttl=30m \
#   -config=@./auth/oidc-auth.json \
#   -http-addr="$DC1"

# # ------------------------------------------
# # Binding rule to map Auth0 groups to Consul roles
# # ------------------------------------------

# # DC1/Proj1 Admins

# consul acl binding-rule create \
#   -method=auth0 \
#   -bind-type=role \
#   -bind-name=team-proj1-rw \
#   -selector='proj1 in list.groups' \
#   -http-addr="$DC1"

# # DC1 Admins

# consul acl binding-rule create \
#   -method=auth0 \
#   -bind-type=role \
#   -bind-name=consul-admins \
#   -selector='admins in list.groups' \
#   -http-addr="$DC1"

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

# consul peering generate-token -name dc2-default -http-addr="$DC1" > tokens/peering-dc1_default-dc2-default.token
# consul peering establish -name dc1-default -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-default.token)

# Peer DC1/default <> DC2/heimdall

# consul peering generate-token -name dc2-heimdall -partition="default" -http-addr="$DC1" > tokens/peering-dc1_default-dc2-heimdall.token
# consul peering establish -name dc1-default -partition="heimdall" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-heimdall.token)

consul peering generate-token -name dc1-default -partition="chunky" -http-addr="$DC2" > tokens/peering-dc2_chunky-dc1-default.token
consul peering establish -name dc2-chunky -partition="default" -http-addr="$DC1" -peering-token $(cat tokens/peering-dc2_chunky-dc1-default.token)

# Peer DC1/unicorn <> DC2/unicorn

# consul peering generate-token -name dc2-unicorn -partition="unicorn" -http-addr="$DC1" > tokens/peering-dc1_unicorn-dc2-unicorn.token
# consul peering establish -name dc1-unicorn -partition="unicorn" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_unicorn-dc2-unicorn.token)

# ==========================================
#          Service Mesh Configs
# ==========================================

# Service Defaults are first, then exports. Per Derek, it's better to set the default before exporting services.

  # ------------------------------------------
  #           service-defaults
  # ------------------------------------------

consul config write -http-addr="$DC1" ./configs/service-defaults/web-defaults.hcl
consul config write -http-addr="$DC1" ./configs/service-defaults/web-upstream-defaults.hcl
consul config write -http-addr="$DC2" ./configs/service-defaults/web-chunky-defaults.hcl

      # Something funky is going on with service-defaults. Must enable the first to get static peer connections working. Can't get service-resolver to work
      # Will leave these commented out for now.

consul config write -http-addr="$DC1" ./configs/service-defaults/unicorn-frontend-defaults.hcl
consul config write -http-addr="$DC1" ./configs/service-defaults/unicorn-backend-defaults.hcl
consul config write -http-addr="$DC2" ./configs/service-defaults/unicorn-backend-defaults.hcl

  # ------------------------------------------
  # Export services across Peers
  # ------------------------------------------

# Export the DC1/Donkey/default/Donkey service to DC1/default/default
consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-donkey.hcl

# Export the default partition services to various peers
consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-dc1-default.hcl
consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-default.hcl

consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-webchunky.hcl

# Export the DC1/unicorn/backend/unicorn-backend service to DC1/unicorn/backend

consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-unicorn_backend.hcl




  # ------------------------------------------
  #              Intentions
  # ------------------------------------------

consul config write -http-addr="$DC1" ./configs/intentions/web_upstream-allow.hcl
consul config write -http-addr="$DC2" ./configs/intentions/web_chunky-allow.hcl

consul config write -http-addr="$DC1" ./configs/intentions/dc1-unicorn_frontend-allow.hcl
consul config write -http-addr="$DC2" ./configs/intentions/dc2-unicorn_frontend-allow.hcl

consul config write -http-addr="$DC1" ./configs/intentions/dc1-unicorn_backend_failover-allow.hcl

  # ------------------------------------------
  #            Service-Resolvers
  # ------------------------------------------

consul config write -http-addr="$DC1" ./configs/service-resolver/dc1-unicorn-backend-failover.hcl

# ------------------------------------------
# Test STUFF
# ------------------------------------------

# curl -sL --header "X-Consul-Token: root" "localhost:8500/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq
# curl -sL --header "X-Consul-Token: root" "localhost:8500/v1/discovery-chain/unicorn-backend?ns=frontend&partition=unicorn" | jq

# curl -sL --header "X-Consul-Token: root" "$DC1/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq
# curl -sL --header "X-Consul-Token: root" "$DC2/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq


# You can specify config entries in the agent config. This might simplify some of the config.

# config_entries {
#    bootstrap {
#       kind = "proxy-defaults"
#       name = "global"
#       config {
#          envoy_dogstatsd_url = "udp://127.0.0.1:9125"
#       }
#    }
#    bootstrap {
#       kind = "service-defaults"
#       name = "foo"
#       protocol = "tcp"
#    }
# }

