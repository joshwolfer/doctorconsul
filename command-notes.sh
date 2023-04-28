# ==========================================
#  THIS file is meant for reference commands, not running as a script.
#  It's only labeled as .sh so I can have syntax coloring in VSC ;)
# ==========================================

# Generating PKI Keys

consul tls ca create -days=3650
consul tls cert create -server -dc=dc1 -additional-dnsname=consul-server1-dc1 -days=1825
consul tls cert create -server -dc=dc2 -additional-dnsname=consul-server1-dc2 -days=1825
chmod 644 *

# Write a config file

consul config write ./configs/whatever.hcl

# Register / de-register an external service

curl --request PUT --data @./configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register

curl --request PUT --data @./configs/services/dc1-proj1-baphomet-dereg.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/deregister


# Resolving the IP for docker containers, including k3d ingress

docker network inspect doctorconsul_wan | jq -r '.[].Containers' | jq -r '.[] | .Name + ":" + .IPv4Address' | grep k3d-k3d-serverlb | cut -d: -f2 | cut -d/ -f1


# ==========================================
#       Admin Partition Management
# ==========================================


$ consul partition create -name <partition> -http-addr="$DC2"
$ consul partition delete <partition> -http-addr="$DC2"

# ==========================================
#             Service Resolution
# ==========================================

# ------------------------------------------
#                   Tips ;)
# ------------------------------------------

jq -r '.[].Service.ID'
curl 'localhost:8500/v1/health/service/<service_name>?partition=<partition>&ns=<namespace>'

# ------------------------------------------
#             Local Resolution
# ------------------------------------------

curl --header "X-Consul-Token: root" "$DC1"/v1/health/service/joshs-obnoxiously-long-service-name-gonna-take-awhile | jq -r '.[].Service.ID'
curl --header "X-Consul-Token: root" "$DC1"/v1/catalog/service/joshs-obnoxiously-long-service-name-gonna-take-awhile?partition=default | jq -r '.[].ServiceID'


    # Root can resolve anything, anywhere.
curl --header "X-Consul-Token: root" "$DC1"/v1/catalog/service/donkey?partition=donkey | jq -r '.[].ServiceID'

# ------------------------------------------
#    Exported-services - Local partitions
# ------------------------------------------

    # Pulling the donkey(AP)/donkey service that are exported from donkey(AP) > Default AP.
    # Health and Catalog API endpoints

# NOTE: The following is broken in 1.13, due to local exported services needing service:write and we only have service:read (because sensible policies). 1.14 should fix it

curl -s --header "X-Consul-Token: 00000000-0000-0000-0000-000000003333" "$DC1"/v1/health/service/donkey?partition=donkey | jq -r '.[].Service.ID'
curl -s --header "X-Consul-Token: 00000000-0000-0000-0000-000000003333" "$DC1"/v1/catalog/service/donkey?partition=donkey | jq -r '.[].ServiceID'



curl -sk --header "X-Consul-Token: root" 'https://127.0.0.1:8502/v1/catalog/service/unicorn-backend?ns=unicorn&partition=cernunnos' | jq -r '.[].ServiceAddress'

curl 'localhost:8500/v1/health/service/payments?'

# ------------------------------------------
#    Exported-services - Cluster Peers
# ------------------------------------------

curl --header "X-Consul-Token: root" "$DC1"/v1/health/service/josh?peer=DC2 | jq -r '.[].Service.ID'
curl --header "X-Consul-Token: root" "$DC2"/v1/health/service/joshs-obnoxiously-long-service-name-gonna-take-awhile?peer=DC1 | jq -r '.[].Service.ID'

# ------------------------------------------
#               Peering
# ------------------------------------------

# Read contents of peering tokens
cat tokens/peering-dc1_default-DC2-heimdall.token | base64 -d | jq

# Display CA cert details
cat tokens/peering-dc1_default-DC2-heimdall.token | base64 -d | jq -r '.CA[0]' | openssl x509 -text -noout

# Verify peering state / details

consul peering list

consul peering read -http-addr="$DC1" -name DC2-default
consul peering read -http-addr="$DC1" -name DC2-heimdall

consul peering read -http-addr="$DC2" -name DC1-default


# ==========================================
#           Services and Configs
# ==========================================

consul config read -http-addr="$DC1" -kind service-defaults -name web2


# ==========================================

consul acl policy create -name unicorn -partition=unicorn -namespace=default -rules @./acl/dc1-unicorn-frontend.hcl

consul acl token create \
    -partition=unicorn \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000004444" \
    -policy-name=unicorn \
    -http-addr="$DC1"

docker kill unicorn-frontend
docker kill unicorn-frontend_envoy

agent.cache: handling error in Cache.Notify: cache-type=peer-trust-bundle error="rpc error: code = Unknown desc = Permission denied: token with AccessorID 'd648aba7-e243-1a82-4dbf-1969150c8e4b' lacks permission 'service:write' on \"any service\" in partition \"unicorn\" in namespace \"default\"" index=0

consul-client-dc1-unicorn        | 2023-03-09T20:53:12.992Z [WARN]  agent.cache: handling error in Cache.Notify: cache-type=peer-trust-bundle error="rpc error: code = Unknown desc = Permission denied: token with AccessorID 'd648aba7-e243-1a82-4dbf-1969150c8e4b' lacks permission 'service:write' on \"any service\" in partition \"unicorn\" in namespace \"default\"" index=0


# ==========================================

service "whateverIwant" {
  policy = "write"
}

namespace_prefix "" {
  service_prefix "" {
      policy     = "read"
  }
  node_prefix "" {
      policy = "read"
  }
}

namespace "frontend" {
  service_prefix "unicorn-frontend"{
    policy  = "write"
  }
}


docker logs consul-server1-dc1 -f



consul-client-dc1-unicorn        | 2023-03-14T01:19:49.689Z [WARN]  agent.cache: handling error in Cache.Notify: cache-type=peer-trust-bundle error="rpc error: code = Unknown desc = Permission denied: token with AccessorID '9a93399b-2671-4271-a05e-70308a531607' lacks permission 'service:write' on \"any service\" in partition \"default\" in namespace \"default\"" index=0

curl --header "X-Consul-Token: root" --request GET http://127.0.0.1:8500/v1/acl/token/73700bd7-3abc-d4e0-9808-a7a2b42aa332