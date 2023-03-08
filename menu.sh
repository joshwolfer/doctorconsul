#!/bin/bash

export CONSUL_HTTP_TOKEN=root

DC1="http://127.0.0.1:8500"
DC2="http://127.0.0.1:8501"
DC3="http://127.0.0.1:8502"

RED='\033[1;31m'
BLUE='\033[1;34m'
DGRN='\033[0;32m'
GRN='\033[1;32m'
YELL='\033[0;33m'
NC='\033[0m' # No Color

clear

# ==========================================
#           1 Service Discovery
# ==========================================

ServiceDiscovery () {

    echo -e "${GRN}"
    echo -e "=========================================="
    echo -e "            Service Discovery "
    echo -e "==========================================${NC}"
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=("1" "2" "3" "Go Back")
    select option in "${options[@]}"; do
        case $option in
            "1")
                echo ""
                echo "Option 1"

                ;;
            "2")
                echo ""
                echo "Option 2"

                ;;
            "3")
                echo ""
                echo "Option 3"

                ;;
            "Go Back")
                echo ""
                clear
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
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
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=("Register Virtual-Baphomet" "De-register Virtual-Baphomet Node" "3" "Go Back")
    select option in "${options[@]}"; do
        case $option in
            "Register Virtual-Baphomet")
                echo ""
                echo -e "${GRN}Registering Virtual-Baphomet${NC}"

                curl --request PUT --data @./configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
                curl --request PUT --data @./configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
                curl --request PUT --data @./configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register

                echo ""
                REPLY=
                ;;
            "De-register Virtual-Baphomet Node")
                echo ""
                echo -e "${GRN}De-registering 'virtual' Node${NC}"

                curl --request PUT --data @./configs/services/dc1-proj1-baphomet-dereg.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/deregister

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
    PS3=$'\n\033[1;31mChoose an option: \033[0m'
    options=("Nuke Unicorn-Backend (DC1) Container" "Restart Unicorn-Backend (DC1) Container" "Do Kube stuff (later)" "Go Back")
    select option in "${options[@]}"; do
        case $option in
            "Nuke Unicorn-Backend (DC1) Container")
                echo ""
                echo -e "${GRN}Killing unicorn-backend (DC1) container...${NC}"

                docker kill unicorn-backend-dc1

                echo ""
                echo -e "${YELL}Traffic from Unicorn-Frontend Service-Resolver (left side) should now route to Unicorn-Backend (DC2)${NC}"
                echo ""
                REPLY=
                ;;
            "Restart Unicorn-Backend (DC1) Container")
                echo ""
                echo -e "${GRN}Restarting Unicorn-Backend (DC1) Container...${NC}"

                docker start unicorn-backend-dc1

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
options=("Service Discovery" "Manipulate Services" "Unicorn Demo" "Quit")
echo ""
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

