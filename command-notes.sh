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

curl --request PUT --data @./configs/services-dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services-dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
curl --request PUT --data @./configs/services-dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register

curl --request PUT --data @./configs/services-dc1-proj1-baphomet-dereg.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/deregister

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

