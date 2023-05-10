#!/bin/bash

export CONSUL_HTTP_TOKEN=root

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"
DC3="https://127.0.0.1:8502"
DC4="https://127.0.0.1:8503"
DC5=""
DC6=""

KDC3="k3d-dc3"
KDC3_P1="k3d-dc3-p1"
KDC4="k3d-dc4"

# RED='\033[1;31m'
# BLUE='\033[1;34m'
# DGRN='\033[0;32m'
# GRN='\033[1;32m'
# YELL='\033[0;33m'
# NC='\033[0m' # No Color

RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
DGRN=$(tput setaf 2)
GRN=$(tput setaf 10)
YELL=$(tput setaf 3)
NC=$(tput sgr0)


COLUMNS=12

clear

# ==========================================
#           1.1 Donkey Discovery
# ==========================================

DonkeyDiscovery () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "    DC1/donkey/donkey (local AP export) "
    echo -e "==========================================${NC}"
    echo ""
    echo -e "${YELL}DC1/Default Read-Only Token: 00000000-0000-0000-0000-000000003333${NC}"
    echo -e "${YELL}DC1/donkey/default/donkey is exported to the default AP${NC}"
    echo ""
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "API Discovery (health + catalog endpoints)"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "API Discovery (health + catalog endpoints)")
                echo ""
                echo -e "${YELL} Resolving DC1/donkey/donkey using the 'service' API: ${NC}"
                echo -e "${GRN} curl -s "$DC1"/v1/health/service/donkey?partition=donkey | jq -r '.[].Service.ID'${NC}"
                curl -s --header "X-Consul-Token: 00000000-0000-0000-0000-000000003333" "$DC1"/v1/health/service/donkey?partition=donkey | jq -r '.[].Service.ID'
                echo ""
                echo -e "${YELL} Resolving DC1/donkey/donkey using the 'catalog' API: ${NC}"
                echo -e "${GRN} curl -s "$DC1"/v1/catalog/service/donkey?partition=donkey | jq -r '.[].ServiceID' ${NC}"
                curl -s --header "X-Consul-Token: 00000000-0000-0000-0000-000000003333" "$DC1"/v1/catalog/service/donkey?partition=donkey | jq -r '.[].ServiceID'
                echo ""
                REPLY=
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# ==========================================
#           1 Service Discovery
# ==========================================

ServiceDiscovery () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Service Discovery "
    echo -e "==========================================${NC}"
    echo ""
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "DC1/donkey/donkey (local AP export)"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "DC1/donkey/donkey (local AP export)")
                DonkeyDiscovery
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
        REPLY=
    done
}

# ==========================================
#         2 Manipulate Services
# ==========================================

ManipulateServices () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Manipulate Services"
    echo -e "=========================================="
    echo -e "${NC}"
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "Register Virtual-Baphomet"
        "De-register Virtual-Baphomet Node"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "Register Virtual-Baphomet")
                echo ""
                echo -e "${GRN}Registering Virtual-Baphomet${NC}"

                curl --request PUT --data @./configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
                curl --request PUT --data @./configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
                curl --request PUT --data @./configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register

                echo ""
                echo ""
                REPLY=
                ;;
            "De-register Virtual-Baphomet Node")
                echo ""
                echo -e "${GRN}De-registering 'virtual' Node${NC}"

                curl --request PUT --data @./configs/services/dc1-proj1-baphomet-dereg.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/deregister

                echo ""
                echo ""
                REPLY=
                ;;
            "3")
                echo ""
                echo "Option 3"

                echo ""
                REPLY=
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# ==========================================
#         3 Unicorn Demo
# ==========================================

UnicornDemo () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Unicorn Demo"
    echo -e "=========================================="
    echo -e "${NC}"
    echo -e "${YELL}The Unicorn-Frontend (DC1) Web UI is accessed from http://127.0.0.1:10000/ui/ ${NC}"
    echo ""
    COLUMNS=12
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "Nuke Unicorn-Backend (DC1) Container"
        "Restart Unicorn-Backend (DC1) Container (root token)"
        "Restart Unicorn-Backend (DC1) Container (standard token)"
        "Nuke Unicorn-Backend (DC2) Container"
        "Restart Unicorn-Backend (DC2) Container (root token)"
        "Restart Unicorn-Backend (DC2) Container (standard token)"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "Nuke Unicorn-Backend (DC1) Container")
                echo ""
                echo -e "${GRN}Killing unicorn-backend (DC1) container...${NC}"

                docker kill unicorn-backend-dc1
                docker kill unicorn-backend-dc1_envoy

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now route to Unicorn-Backend (DC2)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "Restart Unicorn-Backend (DC1) Container (root token)")
                echo ""
                echo -e "${GRN}Restarting Unicorn-Backend (DC1) Container...${NC}"

                docker-compose --env-file docker_vars/acl-root.env up -d 2>&1 | grep --color=never Starting

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now fail-back to Unicorn-Backend (DC1)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "Restart Unicorn-Backend (DC1) Container (standard token)")
                echo -e "${GRN}Restarting Unicorn-Backend (DC1) Container...${NC}"

                docker-compose --env-file docker_vars/acl-secure.env up -d 2>&1 | grep --color=never Starting

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now fail-back to Unicorn-Backend (DC1)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "Nuke Unicorn-Backend (DC2) Container")
                echo ""
                echo -e "${GRN}Killing unicorn-backend (DC3) container...${NC}"

                docker kill unicorn-backend-dc2
                docker kill unicorn-backend-dc2_envoy

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now route to Unicorn-Backend (DC3)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "Restart Unicorn-Backend (DC2) Container (root token)")
                echo ""
                echo -e "${GRN}Restarting Unicorn-Backend (DC2) Container...${NC}"

                docker-compose --env-file docker_vars/acl-root.env up -d 2>&1 | grep --color=never Starting

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now fail-back to Unicorn-Backend (DC1 or DC2)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "Restart Unicorn-Backend (DC2) Container (standard token)")
                echo -e "${GRN}Restarting Unicorn-Backend (DC2) Container...${NC}"

                docker-compose --env-file docker_vars/acl-secure.env up -d 2>&1 | grep --color=never Starting

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now fail-back to Unicorn-Backend (DC1 or DC2)${NC}"
                echo ""
                COLUMNS=12
                REPLY=
                ;;
            "3")
                echo ""
                echo "Option 3"

                echo ""
                REPLY=
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# ==========================================
#            4 Kubernetes
# ==========================================

Kubernetes () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Kubernetes"
    echo -e "=========================================="
    echo -e "${NC}"
    # echo -e "${YELL}The Unicorn-Frontend (DC1) Web UI is accessed from http://127.0.0.1:10000/ui/ ${NC}"
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "Get DC3 LoadBalancer Address"
        "Get DC3 Cernunnos LoadBalancer Address"
        "Update FakeService version in ALL DCs"
        "(DC3) Helm Upgrade (config change)"
        "(DC3 P1 Cernunnos) Helm Upgrade (config change)"
        "Kube ${GRN}Apply${NC} DC3/default/unicorn/unicorn-frontend"
        "Kube ${RED}Delete${NC} DC3/default/unicorn/unicorn-frontend"
        "Kube ${GRN}Apply${NC} DC3/default/unicorn/unicorn-backend"
        "Kube ${RED}Delete${NC} DC3/default/unicorn/unicorn-backend"
        "Kube ${GRN}Apply${NC} DC3/${YELL}cernunnos${NC}/unicorn/unicorn-backend"
        "Kube ${RED}Delete${NC} DC3/${YELL}cernunnos${NC}/unicorn/unicorn-backend"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "Get DC3 LoadBalancer Address")
                echo ""
                echo -e "${YELL}kubectl get service consul-mesh-gateway -nconsul -ojson | jq -r .status.loadBalancer.ingress[0].ip ${NC}"
                kubectl get service consul-mesh-gateway -nconsul -ojson | jq -r .status.loadBalancer.ingress[0].ip
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Get DC3 Cernunnos LoadBalancer Address")
                echo ""
                echo -e "${YELL}kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"' ${NC}"
                kubectl get node k3d-dc3-p1-server-0 --context $KDC3_P1 -o json | jq -r '.metadata.annotations."k3s.io/internal-ip"'
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Update FakeService version in ALL DCs")
                clear
                FAKESERVICE_CUR_VERSION=$(egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+' ./kube/configs/dc3/services/unicorn-frontend.yaml | cut -c 2-)
                echo "FAKESERVICE_VERSION is currently set to: ${GRN}$FAKESERVICE_CUR_VERSION${NC}"

                echo "Enter the desired new version for Fake Service (x.yy.z):"
                while true; do

                    read user_input

                    # Validate the user input against the regex pattern
                    if [[ $user_input =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        export FAKESERVICE_VERSION="$user_input"
                        find ./kube/configs/dc*/services/ -type f -name "*.yaml" -exec grep -l "nicholasjackson/fake-service:v[0-9]*\.[0-9]*\.[0-9]*" {} \; -exec sed -i "s|\(nicholasjackson/fake-service:\)v[0-9]*\.[0-9]*\.[0-9]*|\1v$FAKESERVICE_VERSION|g" {} \;
                        echo ""
                        echo "FAKESERVICE_VERSION is now set to: ${YELL}$FAKESERVICE_VERSION${NC}"
                        echo ""
                        break
                    else
                    # If the input is not valid, print an error message
                    echo "Invalid version number. Enter the desired new version for Fake Service (${RED}x.yy.z${NC}):"
                    fi
                done                
                COLUMNS=1
                REPLY=
                ;;
            "(DC3) Helm Upgrade (config change)")
                echo ""
                echo -e "${YELL}helm upgrade --kube-context $KDC3 consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --debug${NC}"
                helm upgrade --kube-context $KDC3 consul hashicorp/consul -f ./kube/helm/dc3-helm-values.yaml --namespace consul --debug
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "(DC3 P1 Cernunnos) Helm Upgrade (config change)")
                echo ""
                echo -e "${YELL}helm upgrade --kube-context $KDC3_P1 consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul \\"
                echo -e "--set externalServers.k8sAuthMethodHost=$DC3_K8S_IP \\"
                echo -e "--set externalServers.hosts[0]=$DC3_LB_IP \\"
                echo -e "--debug ${NC}"
                helm upgrade --kube-context $KDC3_P1 consul hashicorp/consul -f ./kube/helm/dc3-p1-helm-values.yaml --namespace consul \
                --set externalServers.k8sAuthMethodHost=$DC3_K8S_IP \
                --set externalServers.hosts[0]=$DC3_LB_IP \
                --debug
                echo ""
                COLUMNS=1
                REPLY=
                ;;           
            "Kube ${GRN}Apply${NC} DC3/default/unicorn/unicorn-frontend")
                echo ""
                echo -e "${YELL}kubectl apply --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml ${NC}"
                kubectl apply --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Kube ${RED}Delete${NC} DC3/default/unicorn/unicorn-frontend")
                echo ""
                echo -e "${YELL}kubectl delete --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml ${NC}"
                kubectl delete --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-frontend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Kube ${GRN}Apply${NC} DC3/default/unicorn/unicorn-backend")
                echo ""
                echo -e "${YELL}kubectl apply --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml ${NC}"
                kubectl apply --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Kube ${RED}Delete${NC} DC3/default/unicorn/unicorn-backend")
                echo ""
                echo -e "${YELL}kubectl delete --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml ${NC}"
                kubectl delete --context=$KDC3 -f ./kube/configs/dc3/services/unicorn-backend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Kube ${GRN}Apply${NC} DC3/${YELL}cernunnos${NC}/unicorn/unicorn-backend")
                echo ""
                echo -e "${YELL}kubectl apply --context=$KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml ${NC}"
                kubectl apply --context=$KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Kube ${RED}Delete${NC} DC3/${YELL}cernunnos${NC}/unicorn/unicorn-backend")
                echo ""
                echo -e "${YELL}kubectl delete --context=$KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml ${NC}"
                kubectl delete --context=$KDC3_P1 -f ./kube/configs/dc3/services/unicorn-cernunnos-backend.yaml
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# ==========================================
#            5 Docker Function
# ==========================================

DockerFunction () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Docker Function"
    echo -e "=========================================="
    echo -e "${NC}"
    # echo -e "${YELL}The Unicorn-Frontend (DC1) Web UI is accessed from http://127.0.0.1:10000/ui/ ${NC}"
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "Reload Docker Compose (Root Tokens)"
        "Reload Docker Compose (Secure Tokens)"
        "Reload Docker Compose (Custom Tokens)"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "Reload Docker Compose (Root Tokens)")
                echo ""
                echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-root.env up -d ${NC}"
                echo ""
                docker-compose --env-file docker_vars/acl-root.env up -d
                echo ""
                COLUMNS=1
                break
                ;;
            "Reload Docker Compose (Secure Tokens)")
                echo ""
                echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-secure.env up -d ${NC}"
                echo ""
                docker-compose --env-file docker_vars/acl-secure.env up -d
                echo ""
                COLUMNS=1
                break
                ;;
            "Reload Docker Compose (Custom Tokens)")
                echo ""
                echo -e "${YELL}docker-compose --env-file ./docker_vars/acl-custom.env up -d ${NC}"
                echo ""
                docker-compose --env-file docker_vars/acl-custom.env up -d
                echo ""
                COLUMNS=1
                break
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# ==========================================
#            6 Else Function
# ==========================================

ElseFunction () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "          All the other stuff..."
    echo -e "=========================================="
    echo -e "${NC}"
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "API call template to Consul Servers"
        "Stream logs from Consul Servers"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "API call template to Consul Servers")
                echo ""
                echo -e "${GRN}(DC1)${NC} curl --header \"X-Consul-Token: root\" $DC1/v1/"
                echo -e "${GRN}(DC2)${NC} curl --header \"X-Consul-Token: root\" $DC2/v1/"
                echo -e "${GRN}(DC3)${NC} curl --header \"X-Consul-Token: root\" $DC3/v1/"
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Stream logs from Consul Servers")
                echo ""
                echo -e "${GRN}(DC1)${NC} curl --header \"X-Consul-Token: root\" $DC1/v1/agent/monitor"
                echo -e "${GRN}(DC2)${NC} curl --header \"X-Consul-Token: root\" $DC2/v1/agent/monitor"
                echo -e "${GRN}(DC3)${NC} curl --header \"X-Consul-Token: root\" $DC3/v1/agent/monitor"
                echo ""
                echo -e "For Trace level logging: Add ${YELL}?loglevel=\"trace\" ${NC}"
                echo ""
                echo -e "${GRN}(DC1)${NC} consul monitor -http-addr=$DC1 -token=root -log-level=trace"
                echo -e "${GRN}(DC2)${NC} consul monitor -http-addr=$DC2 -token=root -log-level=trace"
                echo -e "${GRN}(DC3)${NC} consul monitor -http-addr=$DC3 -token=root -log-level=trace"
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "Go Back")
                echo ""
                clear
                COLUMNS=1
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

# restart prometheus
# curl -X POST http://localhost:9090/-/reload



# ==========================================
#              Main Menu
# ==========================================


PS3=$'\n\033[1;31mChoose an option: \033[0m'
options=("Service Discovery" "Manipulate Services" "Unicorn Demo" "Kubernetes" "Docker Compose" "Else")
echo ""
COLUMNS=1
select option in "${options[@]}"; do
    case $option in
        "Service Discovery")
            ServiceDiscovery
            ;;
        "Manipulate Services")
            ManipulateServices
            ;;
        "Unicorn Demo")
            UnicornDemo
            ;;
        "Kubernetes")
            Kubernetes
            ;;
        "Docker Compose")
            DockerFunction
            ;;
        "Else")
            ElseFunction
            ;;
        "Quit")
            echo "User requested exit"
            echo ""
            exit
            ;;
        *)  echo "invalid option $REPLY";;
    esac
    REPLY=
done

            # echo -e "${YELL}Press something to go back"
            # read -s -n 1 -p ""
            # echo -e "${NC}"

