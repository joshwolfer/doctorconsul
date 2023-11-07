#!/bin/bash

set -e

source ./scripts/functions.sh
# # ^^^ Variables and shared functions

help () {
  echo -e "Syntax: ./post-config.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -k3d      Include the default k3d configuration (doesn't accept additional kube-config.sh arguments)"
  echo ""
  exit 0
}

export ARG_HELP=false
export ARG_K3D=false

if [ $# -gt 0 ]; then
  for arg in "$@"; do
    case $arg in
      -help)
        ARG_HELP=true
        ;;
      -k3d)
        ARG_K3D=true
        ;;
      *)
        echo -e "${RED}Invalid Argument... ${NC}"
        echo ""
        help
        exit 1
        ;;
    esac
  done
fi

if $ARG_HELP; then
  help
fi

clear

mkdir -p ./tokens

# echo -e ""
# echo -e "${GRN}iptables: Blocking direct server to server access${NC}"

#   This is to insure that cluster peering is indeed working over mesh gateways.
#   Leaving them commented out so I make sure that other things aren't accidently blocked as we try new features.
#   Specificaly I want to make sure that I can send DNS requests to the servers.

# docker exec -i -t consul-server1-dc1 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.4 -j DROP"  # Block traffic from consul-server1-dc1 to consul-server1-dc2
# docker exec -i -t consul-server1-dc2 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.2 -j DROP"  # Block traffic from consul-server1-dc2 to consul-server-dc1

# echo "success"  # If the script didn't error out here, it worked.

# Wait for both DCs to electe a leader before starting resource provisioning
echo -e ""
echo -e "${GRN}Wait for both DCs to electer a leader before starting resource provisioning${NC}"

# Wait for Leaders to be elected (CONSUL_API_ADDR, Name of DC)
waitForConsulLeader "$DC1" "DC1"
waitForConsulLeader "$DC2" "DC2"

# ==========================================
#            Admin Partitions
# ==========================================

# To prevent possible timing issues in the setup of resources, all admin partitions for all Doctor Consul resources are immediately added first.
# The rest of the application resources, can be found in their respective scripts. 

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

# ==============================================================================================================================
#                                                 Baphomet Application
# ==============================================================================================================================

echo -e "${YELL}Running the Baphomet script:${NC} ./docker-configs/scripts/app-baphomet.sh"
./docker-configs/scripts/app-baphomet.sh


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

echo -e "${GRN}(DC1) default Partition:${NC} $(consul config write -http-addr="$DC1" ./docker-configs/configs/proxy-defaults/dc1-default-proxydefaults.hcl)"
echo -e "${GRN}(DC2) default Partition:${NC} $(consul config write -http-addr="$DC2" ./docker-configs/configs/proxy-defaults/dc2-default-proxydefaults.hcl)"

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

# (1.17) Adds a DNS token so we only need to modify that instead. NMD.

echo -e ""
echo -e "${GRN}Add service:read to the anonymous token (enabling DNS Service Discovery):${NC}"

consul acl policy create -name dns-discovery -rules @./docker-configs/acl/dns-discovery.hcl -http-addr="$DC1"
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name dns-discovery -http-addr="$DC1"

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

consul acl policy create -name dc1-read -rules @./docker-configs/acl/dc1-read.hcl -http-addr="$DC1"
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

# ------------------------------------------
#         Conul-Admins Role (God Mode)
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "      Consul-Admins Role (God Mode)"
echo -e "------------------------------------------${NC}"
echo -e ""

consul acl role create -name consul-admins -policy-name global-management -http-addr="$DC1"

# ==============================================================================================================================
#                                                     OIDC Auth
# ==============================================================================================================================

echo -e "${YELL}Running the Auth0 OIDC script:${NC} ./docker-configs/scripts/oidc-auth0.sh"
./docker-configs/scripts/oidc-auth0.sh

# ==============================================================================================================================
#                                                     JWT Auth
# ==============================================================================================================================

# Coming soon: I haven't figured out JWT auth yet. One day.

# echo -e "${YELL}Running the JWT script:${NC} ./docker-configs/scripts/jwt.sh"
# ./docker-configs/scripts/jwt.sh


# ==========================================
#             Cluster Peering
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

# Set peering to use Mesh Gateways for peering control plane traffic. This must be set BEFORE peering tokens are created.
# Because of the potential timing issues. I have not peered partitions for specific apps (like unicorn / web) in their respective scripts.
# This seemed like a better option. 

echo -e ""
echo -e "${GRN}Set peering to use Mesh Gateways for peering control plane traffic.${NC}"

consul config write -http-addr="$DC1" ./docker-configs/configs/mgw/dc1-mgw.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/mgw/dc2-mgw.hcl

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


  # ------------------------------------------
  # Export services across Peers
  # ------------------------------------------

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# Exported services are scoped to the PARTITION. Only 1 monolithic config can exist per partition.
# Multiple written configs to the same partition will stomp each other. Good times!
# This is addressed in the Consul V2 API

# Export the DC1/Donkey/default/Donkey service to DC1/default/default
consul config write -http-addr="$DC1" ./docker-configs/configs/exported-services/exported-services-donkey.hcl


# Export the default partition services to various peers
consul config write -http-addr="$DC1" ./docker-configs/configs/exported-services/exported-services-dc1-default.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/exported-services/exported-services-dc2-default.hcl

# ==============================================================================================================================
#                                                 Unicorn Application
# ==============================================================================================================================

echo -e "${YELL}Running the Unicorn script:${NC} ./docker-configs/scripts/app-unicorn.sh"
./docker-configs/scripts/app-unicorn.sh

# ==============================================================================================================================
#                                                   Web Application
# ==============================================================================================================================

echo ""
echo -e "${YELL}Running the Web script:${NC} ./docker-configs/scripts/app-web.sh"
./docker-configs/scripts/app-web.sh

# ==========================================
#               k3d config
# ==========================================

if $ARG_K3D; then
  echo -e "${GRN} Launching k3d configuration script (kube-config.sh) ${NC}"
  ./kube-config.sh -k3d-full
  echo ""
fi

# ==============================================================================================================================
#                                                          Outputs
# ==============================================================================================================================

./docker-configs/scripts/vm-outputs.sh

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



