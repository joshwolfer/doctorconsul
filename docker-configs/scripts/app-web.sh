#!/bin/bash

# ==========================================
#        Web Application Resources
# ==========================================

# ==========================================
#            Admin Partitions
# ==========================================

#  The Web Application admin partition is created immediately by the post-config script so that it doesn't hork the registration of the Consul agents and mesh gateways.
#  If we put it here, it'd probably cause a timing issue.

  # ------------------------------------------
  #           proxy-defaults
  # ------------------------------------------

echo -e ""
echo -e "${GRN}proxy-defaults:${NC}"
echo -e ""

echo -e "${GRN}(DC2) chunky Partition:${NC}  $(consul config write -http-addr="$DC2" ./docker-configs/configs/proxy-defaults/dc2-chunky-proxydefaults.hcl)"

# ------------------------------------------
#         Create ACL tokens in DC1
# ------------------------------------------

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

# ------------------------------------------------------------------------------------

# Service Token for Node: web-upstream-dc1_envoy
echo -e ""
echo -e "${GRN}ACL Token: 000000008888 (web-upstream:dc1):${NC}"

consul acl token create \
    -service-identity=web-upstream:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000008888" \
    -accessor="00000000-0000-0000-0000-000000008888" \
    -http-addr="$DC1"

# ------------------------------------------
#        Create ACL tokens in DC2
# ------------------------------------------

# ------------------------------------------------------------------------------------

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
#           service-defaults
# ------------------------------------------

# Service Defaults are first, then exports. Per Derek, it's better to set the default before exporting services.

echo -e ""
echo -e "${GRN}service-defaults:${NC}"

consul config write -http-addr="$DC1" ./docker-configs/configs/service-defaults/web-defaults.hcl
consul config write -http-addr="$DC1" ./docker-configs/configs/service-defaults/web-upstream-defaults.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/service-defaults/web-chunky-defaults.hcl

      # Something funky is going on with service-defaults. Must enable the first to get static peer connections working. Can't get service-resolver to work
      # Will leave these commented out for now.

# ------------------------------------------
# Export services across Peers
# ------------------------------------------

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# DC2/chunky
consul config write -http-addr="$DC2" ./docker-configs/configs/exported-services/exported-services-dc2-chunky.hcl

# ------------------------------------------
#              Intentions
# ------------------------------------------

echo -e ""
echo -e "${GRN}Service Intentions:${NC}"

consul config write -http-addr="$DC1" ./docker-configs/configs/intentions/web_upstream-allow.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/intentions/web_chunky-allow.hcl

# ------------------------------------------
#              Sameness Groups
# ------------------------------------------

echo -e ""
echo -e "${GRN}Sameness Group 'Web':${NC}"
consul config write -http-addr="$DC1" ./docker-configs/configs/sameness-groups/dc1-default-ssg-web.hcl

# consul config list -kind sameness-group
# consul config read -kind sameness-group -name web

# ------------------------------------------
#             Prepared Query
# ------------------------------------------

curl $DC1/v1/query \
    --request POST \
    --header "X-Consul-Token: root" \
    --data @./docker-configs/configs/prepared_queries/pq-web-chunky-sg.json


curl $DC1/v1/query \
    --request POST \
    --header "X-Consul-Token: root" \
    --data @./docker-configs/configs/prepared_queries/pq-web-chunky-peer.json


# list PQs
# curl -s $DC1/v1/query --header "X-Consul-Token: root" | jq -r '.[].Name'


