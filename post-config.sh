#!/bin/bash

set -e

# export the variable to be used by the commands below
export CONSUL_HTTP_TOKEN=root
export CONSUL_HTTP_ADDR=127.0.0.1:8500
export CONSUL_HTTP_SSL_VERIFY=false

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"
DC3="http://127.0.0.1:8502"

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m' # No Color

# Dark Gray     1;30
# Light Red     1;31
# Brown/Orange 0;33     Yellow        1;33
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37

# echo -e "  Consul versions: ${LINK}https://hub.docker.com/r/hashicorp/consul-enterprise/tags${NC}"

if [[ "$*" == *"help"* ]]
  then
    echo -e "Syntax: ./post-config.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k3d      Include the default k3d configuration (doesn't accept additional k3d-config.sh arguments)"
    echo ""
    exit 0
fi

clear

mkdir -p ./tokens

echo -e ""
echo -e "${GRN}iptables: Blocking direct server to server access${NC}"

# Block traffic from consul-server1-dc1 to consul-server1-dc2
docker exec -i -t consul-server1-dc1 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.4 -j DROP"

# Block traffic from consul-server1-dc2 to consul-server-dc1
docker exec -i -t consul-server1-dc2 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.2 -j DROP"
# ^^^ This is to insure that cluster peering is indeed working over mesh gateways.

echo "success"  # If the script didn't error out here, it worked.

# Wait for both DCs to electe a leader before starting resource provisioning
echo -e ""
echo -e "${GRN}Wait for both DCs to electer a leader before starting resource provisioning${NC}"

until curl -s -k ${DC1}/v1/status/leader | grep 8300; do
  echo -e "${RED}Waiting for DC1 Consul to start${NC}"
  sleep 1
done

until curl -s -k ${DC2}/v1/status/leader | grep 8300; do
  echo -e "${RED}Waiting for DC2 Consul to start${NC}"
  sleep 1
done

# ==========================================
#            Admin Partitions
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Admin Partitions"
echo -e "==========================================${NC}"

# Create APs in DC1
echo -e ""
echo -e "${GRN}Create Admin Partitions in DC1${NC}"
consul partition create -name donkey -http-addr="$DC1"
consul partition create -name unicorn -http-addr="$DC1"
consul partition create -name proj1 -http-addr="$DC1"
consul partition create -name proj2 -http-addr="$DC1"

# Create APs in DC2
echo -e ""
echo -e "${GRN}Create Admin Partitions in DC2${NC}"
consul partition create -name unicorn -http-addr="$DC2"
consul partition create -name heimdall -http-addr="$DC2"
consul partition create -name chunky -http-addr="$DC2"

# ==========================================
#                Namespaces
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "                Namespaces"
echo -e "==========================================${NC}"

echo -e ""
echo -e "${GRN}Create Unicorn NSs in DC1${NC}"
# Create Unicorn NSs in DC1
consul namespace create -name frontend -partition=unicorn -http-addr="$DC1"
consul namespace create -name backend -partition=unicorn -http-addr="$DC1"

echo -e ""
echo -e "${GRN}Create Unicorn NSs in DC2${NC}"
# Create Unicorn NSs in DC2
consul namespace create -name frontend -partition=unicorn -http-addr="$DC2"
consul namespace create -name backend -partition=unicorn -http-addr="$DC2"

# ==========================================
#       Register External Services
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "      Register External Services"
echo -e "==========================================${NC}"

# DC1/proj1/virtual-baphomet

echo -e ""
echo -e "${GRN}DC1/Proj1/default/baphomet0${NC}"
curl --request PUT --data @./configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"

echo -e ""
echo -e "${GRN}DC1/Proj1/default/baphomet1${NC}"
curl --request PUT --data @./configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"

echo -e ""
echo -e "${GRN}DC1/Proj1/default/baphomet2${NC}"
curl --request PUT --data @./configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register"


  # ------------------------------------------
  #           proxy-defaults
  # ------------------------------------------

# Managing race conditions....
# 1. When the _envoy side-car containers come up before ACLs have been set, they crash because the ACL doesn't exit.
# 2. So the containers are set to automatically restart on crash.
# 3. The ACL tokens are created in this script and when the Envoys restart, they'll pick up the ACL token.
# 4. proxy-defaults have to be written BEFORE the ACL tokens to make sure the prometheus listener is picked up on Envoy start.
#      Proxy-defaults won't restart Envoy proxies that are already running (/sigh)

# All this ^^^ to TLDR; Proxy-defaults MUST be set BEFORE Envoy side-car ACL tokens.

echo -e ""
echo -e "${GRN}proxy-defaults:${NC}"
echo -e ""
echo -ne "${GRN}(DC1) default Partition: ${NC}"
consul config write -http-addr="$DC1" ./configs/proxy-defaults/dc1-default-proxydefaults.hcl
echo -ne "${GRN}(DC1) unicorn Partition: ${NC}"
consul config write -http-addr="$DC1" ./configs/proxy-defaults/dc1-unicorn-proxydefaults.hcl
echo -ne "${GRN}(DC2) default Partition: ${NC}"
consul config write -http-addr="$DC2" ./configs/proxy-defaults/dc2-default-proxydefaults.hcl
echo -ne "${GRN}(DC2) unicorn Partition: ${NC}"
consul config write -http-addr="$DC2" ./configs/proxy-defaults/dc2-unicorn-proxydefaults.hcl
echo -ne "${GRN}(DC2) chunky Partition: ${NC}"
consul config write -http-addr="$DC2" ./configs/proxy-defaults/dc2-chunky-proxydefaults.hcl

# ==========================================
#             ACLs / Auth N/Z
# ==========================================

echo -e ""
echo -e "${GRN}"
echo -e "=========================================="
echo -e "            ACLs / Auth N/Z"
echo -e "==========================================${NC}"



# ------------------------------------------
# Update the anonymous token so DNS isn't horked
# ------------------------------------------

echo -e ""
echo -e "${GRN}Add service:read to the anonymous token (enabling DNS Service Discovery):${NC}"

consul acl policy create -name dns-discovery -rules @./acl/dns-discovery.hcl -http-addr="$DC1"
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name dns-discovery -http-addr="$DC1"

# ------------------------------------------
#   DC1/unicorn cross namespace discovery
# ------------------------------------------

echo -e ""
echo -e "${GRN}Add DC1/unicorn cross-namespace discovery${NC}"

consul acl policy create \
  -name "cross-namespace-sd" \
  -description "cross-namespace service discovery" \
  -rules @./acl/cross-namespace-discovery.hcl \
  -partition=unicorn \
  -namespace=default \
  -http-addr="$DC1"

consul namespace update -name frontend \
  -default-policy-name="cross-namespace-sd" \
  -partition=unicorn \
  -http-addr="$DC1"

# We need this to make is so unicorn-frontend can read unicorn-backend (discovery).
# But this still doesn't grant read into imported services aross partitions. What a pain in the ass.

# ------------------------------------------
#         Create ACL tokens in DC1
# ------------------------------------------

echo -e ""
echo -e "${GRN}ACL Token: 000000001111:${NC}"

consul acl token create \
    -node-identity=client-dc1-alpha:dc1 \
    -service-identity=joshs-obnoxiously-long-service-name-gonna-take-awhile-and-i-wonder-how-far-we-can-go-before-something-breaks-hrm:dc1 \
    -service-identity=josh:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000001111" \
    -accessor="00000000-0000-0000-0000-000000001111" \
    -http-addr="$DC1"

# DC1 Policy + Role + Token

echo -e ""
echo -e "${GRN}ACL Policy+Role: DC1-read${NC}"

consul acl policy create -name dc1-read -rules @./acl/dc1-read.hcl -http-addr="$DC1"
consul acl role create -name dc1-read -policy-name dc1-read -http-addr="$DC1"

echo -e ""
echo -e "${GRN}ACL Token: 000000003333 (-role-name=dc1-read):${NC}"

consul acl token create \
    -role-name=dc1-read \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000003333" \
    -accessor="00000000-0000-0000-0000-000000003333" \
    -http-addr="$DC1"

# Service Token for Node: web-dc1_envoy

echo -e ""
echo -e "${GRN}ACL Token: 000000007777 (web:dc1):${NC}"

consul acl token create \
    -service-identity=web:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000007777" \
    -accessor="00000000-0000-0000-0000-000000007777" \
    -http-addr="$DC1"

# Service Token for Node: web-dc1_envoy

echo -e ""
echo -e "${GRN}ACL Token: 000000008888 (web-upstream:dc1):${NC}"

consul acl token create \
    -service-identity=web-upstream:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000008888" \
    -accessor="00000000-0000-0000-0000-000000008888" \
    -http-addr="$DC1"

# Service Token for Node: unicorn-frontend-dc1_envoy

echo -e ""
echo -e "${GRN}ACL Token: 000000004444 (-policy-name=unicorn):${NC}"

consul acl policy create -name unicorn -partition=unicorn -namespace=default -rules @./acl/dc1-unicorn-frontend.hcl

# consul acl token create \
#     -partition=unicorn \
#     -namespace=default \
#     -secret="00000000-0000-0000-0000-000000004444" \
#     -accessor="00000000-0000-0000-0000-000000004444" \
#     -policy-name=unicorn \
#     -http-addr="$DC1"

### ^^^ Temporary scoping of the token to the default namespace to figure out what's broken in cluster peering

consul acl token create \
    -service-identity=unicorn-frontend:dc1 \
    -partition=unicorn \
    -namespace=frontend \
    -secret="00000000-0000-0000-0000-000000004444" \
    -accessor="00000000-0000-0000-0000-000000004444" \
    -http-addr="$DC1"

# Service Token for Node: unicorn-backend-dc1_envoy. Still broken with SD of peer endpoints. Keep using the temp one above. 

echo -e ""
echo -e "${GRN}ACL Token: 000000005555 (unicorn-backend:dc1):${NC}"

consul acl token create \
    -service-identity=unicorn-backend:dc1 \
    -partition=unicorn \
    -namespace=backend \
    -secret="00000000-0000-0000-0000-000000005555" \
    -accessor="00000000-0000-0000-0000-000000005555" \
    -http-addr="$DC1"


# ------------------------------------------
#        Create ACL tokens in DC2
# ------------------------------------------

# Service Token for Node: unicorn-backend-dc2_envoy

echo -e ""
echo -e "${GRN}ACL Token: 000000006666 (unicorn-backend:dc2):${NC}"

consul acl token create \
    -service-identity=unicorn-backend:dc2 \
    -partition=unicorn \
    -namespace=backend \
    -secret="00000000-0000-0000-0000-000000006666" \
    -accessor="00000000-0000-0000-0000-000000006666" \
    -http-addr="$DC2"

# Service Token for Node: web-chunky_envoy

echo -e ""
echo -e "${GRN}ACL Token: 000000009999 (web-chunky:dc2):${NC}"

consul acl token create \
    -service-identity=web-chunky:dc2 \
    -partition=chunky \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000009999" \
    -accessor="00000000-0000-0000-0000-000000009999" \
    -http-addr="$DC2"

# ------------------------------------------
#          Partition proj1 RBAC
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         Partition proj1 RBAC"
echo -e "------------------------------------------${NC}"
echo -e ""

echo -e "${GRN}ACL Policy+Role: DC1/proj1/team-proj1-rw${NC}"
consul acl policy create -name team-proj1-rw -rules @./acl/team-proj1-rw.hcl -http-addr="$DC1"
consul acl role create -name team-proj1-rw -policy-name team-proj1-rw -http-addr="$DC1"
echo -e ""
echo -e "${GRN}ACL Token: 000000002222${NC}"
consul acl token create \
    -partition=default \
    -role-name=team-proj1-rw \
    -secret="00000000-0000-0000-0000-000000002222" \
    -accessor="00000000-0000-0000-0000-000000002222" \
    -http-addr="$DC1"

# ------------------------------------------
#             Consul-Admins
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "         Consul-Admins"
echo -e "------------------------------------------${NC}"
echo -e ""

consul acl role create -name consul-admins -policy-name global-management -http-addr="$DC1"

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
  -config=@./auth/oidc-auth.json \
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

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"


# Set peering to use Mesh Gateways for peering control plane traffic. This must be set BEFORE peering tokens are created.

echo -e ""
echo -e "${GRN}Set peering to use Mesh Gateways for peering control plane traffic.${NC}"

consul config write -http-addr="$DC1" ./configs/mgw/dc1-mgw.hcl
consul config write -http-addr="$DC2" ./configs/mgw/dc2-mgw.hcl

# Peer DC1/default <- DC2/default

echo -e ""
echo -e "${GRN}Peer DC1/default <- DC2/default${NC}"

consul peering generate-token -name dc2-default -http-addr="$DC1" > tokens/peering-dc1_default-dc2-default.token
consul peering establish -name dc1-default -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-default.token)

# Peer DC1/default <- DC2/heimdall

echo -e ""
echo -e "${GRN}Peer DC1/default <- DC2/heimdall${NC}"

consul peering generate-token -name dc2-heimdall -partition="default" -http-addr="$DC1" > tokens/peering-dc1_default-dc2-heimdall.token
consul peering establish -name dc1-default -partition="heimdall" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-heimdall.token)

# Peer DC1/default -> DC2/chunky

echo -e ""
echo -e "${GRN}Peer DC1/default -> DC2/chunky${NC}"

consul peering generate-token -name dc1-default -partition="chunky" -http-addr="$DC2" > tokens/peering-dc2_chunky-dc1-default.token
consul peering establish -name dc2-chunky -partition="default" -http-addr="$DC1" -peering-token $(cat tokens/peering-dc2_chunky-dc1-default.token)

# Peer DC1/unicorn <- DC2/unicorn

echo -e ""
echo -e "${GRN}Peer DC1/unicorn <- DC2/unicorn${NC}"

consul peering generate-token -name dc2-unicorn -partition="unicorn" -http-addr="$DC1" > tokens/peering-dc1_unicorn-dc2-unicorn.token
consul peering establish -name dc1-unicorn -partition="unicorn" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_unicorn-dc2-unicorn.token)

# ==========================================
#          Service Mesh Configs
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "          Service Mesh Configs"
echo -e "==========================================${NC}"

# Service Defaults are first, then exports. Per Derek, it's better to set the default before exporting services.

  # ------------------------------------------
  #           service-defaults
  # ------------------------------------------

echo -e ""
echo -e "${GRN}service-defaults:${NC}"

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

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# Exported services are scoped to the PARTITION. Only 1 monolithic config can exist per partition.
# Multiple written configs to the same partition will stomp each other. Good times!

# Export the DC1/Donkey/default/Donkey service to DC1/default/default
consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-donkey.hcl

# Export the DC1/unicorn/backend/unicorn-backend service to DC1/default/default
# This is the only example of a mesh service being exported on a local partition
consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-dc1-unicorn.hcl

# Export the default partition services to various peers
consul config write -http-addr="$DC1" ./configs/exported-services/exported-services-dc1-default.hcl
consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-default.hcl

consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-webchunky.hcl

# Export the DC1/unicorn/backend/unicorn-backend service to DC1/unicorn/backend

consul config write -http-addr="$DC2" ./configs/exported-services/exported-services-dc2-unicorn_backend.hcl



  # ------------------------------------------
  #              Intentions
  # ------------------------------------------

echo -e ""
echo -e "${GRN}Service Intentions:${NC}"

consul config write -http-addr="$DC1" ./configs/intentions/web_upstream-allow.hcl
consul config write -http-addr="$DC2" ./configs/intentions/web_chunky-allow.hcl

consul config write -http-addr="$DC1" ./configs/intentions/dc1-unicorn_frontend-allow.hcl
consul config write -http-addr="$DC2" ./configs/intentions/dc2-unicorn_frontend-allow.hcl

consul config write -http-addr="$DC1" ./configs/intentions/dc1-unicorn_backend_failover-allow.hcl

  # ------------------------------------------
  #            Service-Resolvers
  # ------------------------------------------

echo -e ""
echo -e "${GRN}Service-resolvers:${NC}"

consul config write -http-addr="$DC1" ./configs/service-resolver/dc1-unicorn-backend-failover.hcl
echo -e ""

# ==========================================
#               k3d config
# ==========================================

if [[ "$*" == *"-k3d"* ]]
  then
    echo -e "${GRN} Launching k3d configuration script (k3d-config.sh) ${NC}"
    ./k3d-config.sh
    echo ""
fi





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



