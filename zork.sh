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

RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
DGRN=$(tput setaf 2)
GRN=$(tput setaf 10)
YELL=$(tput setaf 3)
NC=$(tput sgr0)

export FAKESERVICE_VER="v0.26.0"

COLUMNS=12

clear

# ------------------------------------------
#           1.1 Donkey Discovery
# ------------------------------------------

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
                        # find ./kube/configs/dc*/services/ -type f -name "*.yaml" -exec grep -l "nicholasjackson/fake-service:v[0-9]*\.[0-9]*\.[0-9]*" {} \; -exec sed -i "s|\(nicholasjackson/fake-service:\)v[0-9]*\.[0-9]*\.[0-9]*|\1v$FAKESERVICE_VERSION|g" {} \;
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
                echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-root.env up -d ${NC}"
                echo ""
                docker-compose --env-file docker_vars/acl-root.env up -d
                echo ""
                COLUMNS=1
                break
                ;;
            "Reload Docker Compose (Secure Tokens)")
                echo ""
                echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-secure.env up -d ${NC}"
                echo ""
                docker-compose --env-file docker_vars/acl-secure.env up -d
                echo ""
                COLUMNS=1
                break
                ;;
            "Reload Docker Compose (Custom Tokens)")
                echo ""
                echo -e "${YELL}docker-compose --env-file ./docker-configs/docker_vars/acl-custom.env up -d ${NC}"
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


# ------------------------------------------
#      6.1 Else > Chance Component Version
# ------------------------------------------

UpdateFakeService () {
    # clear
    echo "FAKESERVICE_VERSION is currently set to: Kube:${GRN}$FAKESERVICE_KUBE_CUR_VERSION${NC} Docker:${GRN}$FAKESERVICE_DOCKER_CUR_VERSION${NC}"
    echo "Enter the desired new version for Fake Service (x.yy.z):"
    while true; do
        read user_input
        # Validate the user input against the regex pattern
        if [[ $user_input =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            export FAKESERVICE_VERSION="$user_input"
            find ./kube/configs/dc*/services/ -type f -name "*.yaml" -exec grep -l "nicholasjackson/fake-service:v[0-9]*\.[0-9]*\.[0-9]*" {} \; -exec sed -i "s|\(nicholasjackson/fake-service:\)v[0-9]*\.[0-9]*\.[0-9]*|\1v$FAKESERVICE_VERSION|g" {} \;
            find ./docker-configs/docker_vars/ -type f -name "*.env" -exec grep -l "nicholasjackson/fake-service:v[0-9]*\.[0-9]*\.[0-9]*" {} \; -exec sed -i "s|\(nicholasjackson/fake-service:\)v[0-9]*\.[0-9]*\.[0-9]*|\1v$FAKESERVICE_VERSION|g" {} \;
            find ./k3d-config.sh -exec grep -l "IMAGE_FAKESERVICE=" {} \; -exec sed -i "s|\(nicholasjackson/fake-service:\)v[0-9]*\.[0-9]*\.[0-9]*|\1v$FAKESERVICE_VERSION|g" {} \;

            echo ""
            echo "FAKESERVICE_VERSION is now set to: ${YELL}$FAKESERVICE_VERSION${NC}"
            echo ""
            break
        else
        # If the input is not valid, print an error message
        echo "Invalid version number. Enter the desired new version for Fake Service (${RED}x.yy.z${NC}):"
        fi
    done
}

UpdateConsul () {
    # clear
    echo "Consul is currently set to: Kube:${GRN}$CONSUL_KUBE_CUR_VERSION-ent${NC} Docker:${GRN}$CONSUL_DOCKER_CUR_VERSION-ent${NC}"
    echo "Enter the desired new version for Consul (x.yy.z-ent):"
    while true; do
        read user_input
        # Validate the user input against the regex pattern
        if [[ $user_input =~ ^[0-9]+\.[0-9]+\.[0-9]+-ent$ ]]; then
            export CONSUL_VERSION="$user_input"
            find ./kube/helm/dc* -type f -name "*.yaml" -exec grep -l "image: hashicorp/consul-enterprise:" {} \; -exec sed -E -i "s|(image: hashicorp/consul-enterprise:)[0-9]+\.[0-9]+\.[0-9]+-ent|\1$CONSUL_VERSION|g" {} \;
            find ./docker-configs/docker_vars/ -type f -name "*.env" -exec grep -l "CONSUL_IMAGE" {} \; -exec sed -E -i "s|(hashicorp/consul-enterprise:)[0-9]+\.[0-9]+\.[0-9]+-ent|\1$CONSUL_VERSION|g" {} \;
            echo ""
            echo "Consul is now set to: ${YELL}$CONSUL_VERSION${NC}"
            echo ""
            break
        else
        # If the input is not valid, print an error message
        echo "Invalid version number. Enter the desired new version for Fake Service (${RED}x.yy.z-ent${NC}):"
        fi
    done
}

UpdateConvoy () {
    echo "Convoy version is currently set to: ${GRN}$CONVOY_DOCKER_CUR_VERSION${NC}"
    echo "Enter the desired new version for Convoy (vX.XX.X-ent_vX.XX.X):"
    while true; do
        read user_input
        # Validate the user input against the regex pattern
        if [[ $user_input =~ ^v[0-9]+\.[0-9]+\.[0-9]+-ent_v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            export CONVOY_VERSION="$user_input"
            find ./docker-configs/docker_vars/ -type f -name "*.env" -exec grep -l "CONVOY_IMAGE" {} \; -exec sed -E -i "s|(joshwolfer/consul-envoy:)v[0-9]+\.[0-9]+\.[0-9]+-ent_v[0-9]+\.[0-9]+\.[0-9]+|\1$CONVOY_VERSION|g" {} \;
            echo ""
            echo "Convoy is now set to: ${YELL}$CONVOY_VERSION${NC}"
            echo ""
            break
        else
        # If the input is not valid, print an error message
        echo "Invalid version number. Enter the desired new version for Fake Service (${RED}vX.XX.X-ent_vX.XX.X${NC}):"
        fi
    done
}

ShowComponentVersions () {
    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "         Change Component Versions  "
    echo -e "==========================================${NC}"
    echo ""
    echo -e "Current Versions"
    echo ""
    CONSUL_KUBE_CUR_VERSION=$(egrep 'image: hashicorp/consul-enterprise' ./kube/helm/dc3-helm-values.yaml | egrep -o '[0-9]+\.[0-9]+\.[0-9]+')
    FAKESERVICE_KUBE_CUR_VERSION=$(egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+' ./kube/configs/dc3/services/unicorn-frontend.yaml | cut -c 2-)

    CONSUL_DOCKER_CUR_VERSION="$(egrep 'CONSUL_IMAGE' ./docker-configs/docker_vars/acl-custom.env | egrep -o '[0-9]+\.[0-9]+\.[0-9]+')"
    FAKESERVICE_DOCKER_CUR_VERSION=$(egrep 'FAKESERVICE_IMAGE' ./docker-configs/docker_vars/acl-custom.env | egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+' | cut -c 2-)
    CONVOY_DOCKER_CUR_VERSION="$(egrep 'CONVOY_IMAGE' ./docker-configs/docker_vars/acl-custom.env | egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+-ent_v[0-9]+\.[0-9]+\.[0-9]+')"

    echo -e "${YELL}Kubernetes          ${NC} | ${YELL}Docker Compose${NC}"
    echo ""
    echo "Consul: ${GRN}$CONSUL_KUBE_CUR_VERSION-ent   ${NC}| ${GRN}$CONSUL_DOCKER_CUR_VERSION-ent${NC}"
    echo "FakeService: ${GRN}$FAKESERVICE_KUBE_CUR_VERSION  ${NC}| ${GRN}$FAKESERVICE_DOCKER_CUR_VERSION${NC}"
    echo "Convoy: ${GRN}N/A ${NC}         | ${GRN}$CONVOY_DOCKER_CUR_VERSION${NC}"
    echo ""
}

ChangeVersions () {
    clear
    ShowComponentVersions
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "Change Consul Version"
        "Change FakeService Version"
        "Change Convoy Version"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "Change Consul Version")
                echo ""
                UpdateConsul
                clear
                ShowComponentVersions
                echo ""
                REPLY=
                ;;
            "Change FakeService Version")
                echo ""
                UpdateFakeService
                clear
                ShowComponentVersions
                echo ""
                REPLY=
                ;;
            "Change Convoy Version")
                echo ""
                UpdateConvoy
                clear
                ShowComponentVersions
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


k9sAddPlugin () {
    PLUGIN_DIR="$HOME/.config/k9s"
    PLUGIN_FILE="plugin.yml"

    # Create the plugin directory if it doesn't exist
    mkdir -p "${PLUGIN_DIR}"

    # Path to the plugin file
    PLUGIN_PATH="${PLUGIN_DIR}/${PLUGIN_FILE}"

    # Copy the plugin to configuration to the file
    cp ./xtra/k9s/plugin.yml "${PLUGIN_PATH}"

    # Print the status
    echo "Plugin created at ${YELL}${PLUGIN_PATH}${NC}"
    echo "Restart k9s or press '0' in k9s to reload configuration."
    echo ""
    echo "Plugin commands:"
    echo ""
    echo "  Pods View:"
    echo "    ${YELL}Shift + 0${NC}: Scale deployment down to zero"
    echo "    ${YELL}Shift + 1${NC}: Pull Envoy /stats and open in VSC"
    echo "    ${YELL}Shift + 2${NC}: Pull Envoy /clusters and open in VSC"
    echo "    ${YELL}Shift + 3${NC}: Pull Envoy /config_dump and open in VSC"
    echo ""
    echo "  Containers View"
    echo "    ${YELL}Shift + D${NC}: Attach and shell into a Netshoot Debug container"
    echo ""
    echo "  Deployments View"
    echo "    ${YELL}Shift + 0${NC}: Scale deployment 0"
    echo "    ${YELL}Shift + 1${NC}: Scale deployment 1"
    echo "    ${YELL}Shift + 2${NC}: Scale deployment 2"
    echo "    ${YELL}Shift + 3${NC}: Scale deployment 3"
    echo ""
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
        "Change Component Versions"
        "FakeService Kube: Image switch back to PUBLIC registry"
        "FakeService Kube: Image switch back to K3D registry"
        "K9s: Add plugin"
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
            "Change Component Versions")
                echo ""
                ChangeVersions
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "FakeService Kube: Image switch back to PUBLIC registry")
                echo ""
                find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
                find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "FakeService Kube: Image switch back to K3D registry")
                echo ""
                find ./kube/configs/dc3/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
                find ./kube/configs/dc4/services/*.yaml -type f -exec sed -i "s/^\( *\)image: .*/\1image: k3d-doctorconsul.localhost:12345\/nicholasjackson\/fake-service:$FAKESERVICE_VER/" {} \;
                echo ""
                COLUMNS=1
                REPLY=
                ;;
            "K9s: Add plugin")
                echo ""
                k9sAddPlugin
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

VIPandFilterChains () {
    # clear
    echo "Fetch Cluster ID list with:"
    echo "${YELL}curl -s localhost:19000/clusters | grep 'observability_name::' | egrep '\\.consul' | awk -F 'observability_name::' '{print \$2}' | sort ${NC}"
    echo ""
    echo "This tool fetches the VIP and Filter Chains for the matching Cluster ID:"
    echo "${GRN}Example:${NC} unicorn-tp-backend.unicorn.cernunnos.dc3.internal-v1.fcf79bfb-8a73-bb5f-5e9c-c4f9ce725c0a.consul"
    echo ""
    echo "Enter the cluster ID:"
    while true; do
    read -r CLUSTER_ID
    # Validate the user input against the regex pattern
    if [[ -n $CLUSTER_ID ]]; then
        if [[ $CLUSTER_ID == destination.* ]]; then
            export JQ="curl -s localhost:19000/config_dump | jq '.configs[2].dynamic_listeners[] | .active_state.listener.filter_chains[]? | select(.filters[0].typed_config.cluster == \"${CLUSTER_ID}\") | {filter_chain_match, filters} | del(.filters[0].typed_config.access_log)'"
        else
            export JQ="curl -s localhost:19000/config_dump | jq '.configs[2].dynamic_listeners[] | .active_state.listener.filter_chains[]? | select(.filters[0].typed_config.route_config.virtual_hosts[0].routes[0].route.cluster == \"${CLUSTER_ID}\") | del(.filters[0].typed_config.access_log)'"
        fi
        echo ""
        echo "The correct jq filter is:"
        echo "${YELL}$JQ${NC}"
        echo ""
        break
    else
        # If the input is not valid, print an error message
        echo "ClusterID cannot be blank"
    fi
done

}


jqTroubleshootingFiltersMenu () {
    clear
    COLUMNS=1
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=(
        "VIP and filter chains by cluster ID"
        "Go Back"
    )
    select option in "${options[@]}"; do
        case $option in
            "VIP and filter chains by cluster ID")
                echo ""
                VIPandFilterChains
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
#              Main Menu
# ==========================================


PS3=$'\n\033[1;31mChoose an option: \033[0m'
options=("Service Discovery" "Manipulate Services" "Unicorn Demo" "Kubernetes" "Docker Compose" "jq troubleshooting filters" "Else")
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
        "jq troubleshooting filters")
            echo ""
            jqTroubleshootingFiltersMenu
            echo ""
            COLUMNS=1
            REPLY=
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

