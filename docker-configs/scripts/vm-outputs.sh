#!/bin/bash

set -e

# --------------------------------------------------------------------------------------------
# Default Values (overwritten when provisioning to alternate environments (EKS, GKE, ...))
# --------------------------------------------------------------------------------------------

DC1_ADDR=http://127.0.0.1:8500
DC2_ADDR=http://127.0.0.1:8501

DC1_WEB_UI_ADDR=http://localhost:9000/ui/
DC1_UNICORN_FRONTEND_UI_ADDR=http://localhost:10000/ui/
DC1_PROMETHEUS=http://localhost:9090/

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

# ----------------------------------------------
#               Consul Addresses
# ----------------------------------------------

echo ""
echo -e "${GRN}------------------------------------------"
echo -e "             VM-Style Outputs"
echo -e "------------------------------------------${NC}"
echo ""

echo -e "${GRN}Consul UI Addresses: ${NC}"
echo -e " ${YELL}DC1${NC}: $DC1_ADDR/ui/"
echo -e " ${YELL}DC2${NC}: $DC2_ADDR/ui/"
echo -e ""
echo -e "${RED}Don't forget to login to the UI using token${NC}: 'root'"
echo -e ""

echo -e "${GRN}Export ENV Variables ${NC}"
echo -e " export DC1=$DC1_ADDR"
echo -e " export DC2=$DC2_ADDR"
echo -e " export CONSUL_HTTP_TOKEN=root"
echo ""


# ----------------------------------------------
#               Fake Service Addresses
# ----------------------------------------------

echo -e "${GRN}Fake Service UI addresses: ${NC}"
echo -e " ${YELL}DC1 Web:${NC} $DC1_WEB_UI_ADDR"
echo -e " ${YELL}DC1 Unicorn-Frontend:${NC} $DC1_UNICORN_FRONTEND_UI_ADDR"
echo -e " ${YELL}DC1 Prometheus WebUI:${NC} $DC1_PROMETHEUS"
echo ""

# ----------------------------------------------
#                  Footer
# ----------------------------------------------
echo -e "${RED}Happy Consul'ing! ${NC}"
echo -e ""
