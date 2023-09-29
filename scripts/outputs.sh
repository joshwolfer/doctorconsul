#!/bin/bash

set -e

# --------------------------------------------------------------------------------------------
# Default Values (overwritten when provisioning to alternate environments (EKS, GKE, ...))
# --------------------------------------------------------------------------------------------

DC3_ADDR=https://127.0.0.1:8502
DC4_ADDR=https://127.0.0.1:8503

UNICORN_FRONTEND_UI_ADDR=http://127.0.0.1:11000
UNICORN_SSG_FRONTEND_UI_ADDR=http://localhost:11001/ui/

DC3_EXTERNALZ_TCP_ADDR=http://127.0.0.1:8002/ui/
DC3_EXTERNALZ_HTTP_ADDR=http://127.0.0.1:8003/ui/

DC4_SHEOL_ADDR=http://127.0.0.1:8004/ui/
DC4_SHEOL1_ADDR=http://127.0.0.1:8005/ui/
DC4_SHEOL2_ADDR=http://127.0.0.1:8006/ui/

DC3_CONSUL_API_GATEWAY_ADDR=http://127.0.0.1

DC3_P1_PARIS_LEROY_ADDR=http://127.0.0.1:8100/ui/
DC3_P1_PARIS_PLEASE_ADDR=http://127.0.0.1:8101/ui/

DC3_P1_NEAPOLITAN_ADDR=http://127.0.0.1:8007/ui/

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

if $ARG_EKSONLY; then

  DC3_LB_IP=$(cat ./tokens/dc3_lb_ip.txt)     # When -outputs is run after the initial provision, we have to re-pull the address from the text file.
  DC4_LB_IP=$(cat ./tokens/dc4_lb_ip.txt)     # ^^^

  DC3_ADDR=http://$DC3_LB_IP:8500
  DC4_ADDR=http://$DC4_LB_IP:8500

  if [[ "$ARG_NO_APPS" == "false" ]]; then
    echo -e "${RED}Generating Outputs (Might take a second to run all the checks...) ${NC}"
    echo ""


    export UNICORN_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')
    # export UNICORN_SSG_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')

    # # ------------------------------------------
    # #  (DC3) Wait and Consul API GW
    # # ------------------------------------------

    # APIG has two ports, can't use the wait_for_kube_service_w_port() function

    while true; do
        DC3_CONSUL_API_GATEWAY_HOSTNAME=$(kubectl get svc consul-api-gateway -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')

        if [ ! -z "$DC3_CONSUL_API_GATEWAY_HOSTNAME" ]; then
            DC3_CONSUL_API_GATEWAY_ADDR=http://$DC3_CONSUL_API_GATEWAY_HOSTNAME
            break
        fi

        echo "Waiting for the consul-api-gateway load balancer to get an ingress hostname..."
        sleep 2
    done

    # Function to wait for service to get its ingress hostname
    wait_for_kube_service_w_port() {
      local svc_name=$1        # Kube service name
      local namespace=$2       # Kube namespace
      local context=$3         # Kube context
      local max_retries=$4
      local port_suffix=$5
      local counter=0
      local hostname_var_name=$6      # I dunno. chatgpt magic. Just follow suit, I guess.
      local addr_var_name=$7          # Variable name to reference in this script

      while [ $counter -lt $max_retries ]; do
        local hostname=$(kubectl get svc $svc_name -n$namespace --context $context -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
        local port=$(kubectl get svc $svc_name -n$namespace --context $context -o jsonpath='{.spec.ports[0].port}')

        if [ ! -z "$hostname" ]; then
          eval "$hostname_var_name=$hostname"
          eval "$addr_var_name=http://$hostname:$port$port_suffix"
          break
        fi

        counter=$((counter+1))
        if [ $counter -eq $max_retries ]; then
          echo "Giving up on $svc_name after $max_retries attempts."
          break
        fi

        echo "Waiting for $svc_name load balancer to get an ingress hostname... Attempt $counter/$max_retries."
        sleep 2
      done
    }

    # Usage
    wait_for_kube_service_w_port "unicorn-ssg-frontend" "unicorn" "$KDC3" 6 "/ui/" "SSG_HOSTNAME" "UNICORN_SSG_FRONTEND_UI_ADDR"
    wait_for_kube_service_w_port "externalz-tcp" "externalz" "$KDC3" 6 "/ui/" "DC3_EXTERNALZ_TCP_HOSTNAME" "DC3_EXTERNALZ_TCP_ADDR"
    wait_for_kube_service_w_port "externalz-http" "externalz" "$KDC3" 6 "/ui/" "DC3_EXTERNALZ_HTTP_HOSTNAME" "DC3_EXTERNALZ_HTTP_ADDR"
    wait_for_kube_service_w_port "sheol-app" "sheol" "$KDC4" 6 "/ui/" "DC4_SHEOL_HOSTNAME" "DC4_SHEOL_ADDR"
    wait_for_kube_service_w_port "sheol-app1" "sheol-app1" "$KDC4" 6 "/ui/" "DC4_SHEOL1_HOSTNAME" "DC4_SHEOL1_ADDR"
    wait_for_kube_service_w_port "sheol-app2" "sheol-app2" "$KDC4" 6 "/ui/" "DC4_SHEOL2_HOSTNAME" "DC4_SHEOL2_ADDR"
    # wait_for_kube_service_w_port "consul-api-gateway" "consul" "$KDC3" 6 "" "DC3_CONSUL_API_GATEWAY_HOSTNAME" "DC3_CONSUL_API_GATEWAY_ADDR"    # APIG has two ports, can't use this function for now
    wait_for_kube_service_w_port "leroy-jenkins" "paris" "$KDC3_P1" 6 "/ui/" "DC3_P1_PARIS_LEROY_HOSTNAME" "DC3_P1_PARIS_LEROY_ADDR"
    wait_for_kube_service_w_port "pretty-please" "paris" "$KDC3_P1" 6 "/ui/" "DC3_P1_PARIS_PLEASE_HOSTNAME" "DC3_P1_PARIS_PLEASE_ADDR"
    wait_for_kube_service_w_port "neapolitan" "banana-split" "$KDC3_P1" 6 "/ui/" "DC3_P1_NEAPOLITAN_HOSTNAME" "DC3_P1_NEAPOLITAN_ADDR"
  else
    echo "Skipping Application Detection (-no-apps)"
  fi
fi

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

# ----------------------------------------------
#                   Title
# ----------------------------------------------

if $ARG_NO_APPS; then
    echo -e "${RED} Consul is installed. Exiting before applications are installed! ${NC}"
    echo -e ""

    echo -e "${GRN}------------------------------------------"
    echo -e "  No Installed Apps (Kube Clusters only)"
    echo -e "------------------------------------------${NC}"
    echo -e ""

  elif $ARG_EKSONLY; then
    echo -e "${GRN}"
    echo -e "------------------------------------------"
    echo -e "            EKSOnly Outputs"
    echo -e "------------------------------------------${NC}"
    echo -e ""

  else
    echo -e "${GRN}------------------------------------------"
    echo -e "            K3d Outputs"
    echo -e "------------------------------------------${NC}"
    echo -e ""
fi

# ----------------------------------------------
#               Consul Addresses
# ----------------------------------------------

echo -e "${GRN}Consul UI Addresses: ${NC}"
echo -e " ${YELL}DC3${NC}: $DC3_ADDR/ui/"
echo -e " ${YELL}DC4${NC}: $DC4_ADDR/ui/"
echo -e ""
echo -e "${RED}Don't forget to login to the UI using token${NC}: 'root'"
echo -e ""

echo -e "${GRN}Export ENV Variables ${NC}"
echo -e " export DC3=$DC3_ADDR"
echo -e " export DC4=$DC4_ADDR"
echo -e " export CONSUL_HTTP_TOKEN=root"
echo ""
echo -e " export KDC3=k3d-dc3"
echo -e " export KDC3_P1=k3d-dc3-p1"
echo -e " export KDC4=k3d-dc4"
echo -e " export KDC4_P1=k3d-dc4-p1"
echo -e ""

# ----------------------------------------------
#              Port Forwards
# ----------------------------------------------

if $ARG_NO_APPS; then
    echo -e "${GRN}Port forwards to map services / UI to traditional Doctor Consul local ports: ${NC}"
    echo -e " kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &"
    echo -e " kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &"
    echo -e ""

  elif $ARG_EKSONLY; then
    echo -e "${GRN}Port forwards to map services / UI to traditional Doctor Consul local ports: ${NC}"
    echo -e " kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &"
    echo -e " kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &"
    echo -e " kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-frontend 11000:8000 > /dev/null 2>&1 &"        # Doesn't work for some reason
    echo -e " kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-ssg-frontend 11001:8001  > /dev/null 2>&1 &"   # Doesn't work for some reason
    echo -e " kubectl -nexternalz --context $KDC3 port-forward svc/externalz-tcp 8002:8002 > /dev/null 2>&1 &"
    echo -e " kubectl -nexternalz --context $KDC3 port-forward svc/externalz-http 8003:8003 > /dev/null 2>&1 &"
    echo -e " kubectl -nconsul --context $KDC3 port-forward svc/consul-api-gateway 1666:1666 > /dev/null 2>&1 &"
    echo -e " kubectl -nconsul --context $KDC3 port-forward svc/consul-api-gateway 1667:1667 > /dev/null 2>&1 &"
    echo -e " kubectl -nsheol --context $KDC4 port-forward svc/sheol-app 8004:8004 > /dev/null 2>&1 &"
    echo -e " kubectl -nsheol-app1 --context $KDC4 port-forward svc/sheol-app1 8005:8005 > /dev/null 2>&1 &"
    echo -e " kubectl -nsheol-app2 --context $KDC4 port-forward svc/sheol-app2 8006:8006 > /dev/null 2>&1 &"
    echo -e " kubectl -nparis --context $KDC3_P1 port-forward svc/leroy-jenkins 8100:8100 > /dev/null 2>&1 &"
    echo -e " kubectl -nparis --context $KDC3_P1 port-forward svc/pretty-please 8101:8101 > /dev/null 2>&1 &"
    # Add forward for Neapolitan...
    echo -e ""
fi

# ----------------------------------------------
#               Fake Service Addresses
# ----------------------------------------------

if $ARG_NO_APPS; then
    echo ""

  else

    echo -e "${GRN}Fake Service UI addresses: ${NC}"
    echo -e " ${YELL}Unicorn-Frontend:${NC} $UNICORN_FRONTEND_UI_ADDR/ui/"
    echo -e " ${YELL}Unicorn-SSG-Frontend:${NC} $UNICORN_SSG_FRONTEND_UI_ADDR"
    echo ""
    echo -e "${GRN}Externalz-tcp UI address: ${NC}"
    echo -e " ${YELL}Externalz-tcp:${NC} $DC3_EXTERNALZ_TCP_ADDR"
    echo -e " ${YELL}Externalz-tcp:${NC} $DC3_EXTERNALZ_HTTP_ADDR"
    echo -e ""
    echo -e "${GRN}Sheol App UI addresses (External Services via TGW): ${NC}"
    echo -e " ${YELL}Sheol-App:${NC} $DC4_SHEOL_ADDR"
    echo -e " ${YELL}Sheol-App1:${NC} $DC4_SHEOL1_ADDR"
    echo -e " ${YELL}Sheol-App2:${NC} $DC4_SHEOL2_ADDR"
    echo -e ""
    echo -e "${GRN}Consul API-GW LB Address: ${NC}"
    echo -e " ${YELL}Consul APIG HTTP Listener:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1666"
    echo -e "  ${YELL}Consul APIG HTTP Apps:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1666/unicorn-frontend/ui/"
    echo -e "  ${YELL}Consul APIG HTTP Apps:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1666/unicorn-ssg-frontend/ui/"
    echo -e "  ${YELL}Consul APIG HTTP Apps:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1666/externalz-http/ui/"
    echo -e " ${YELL}Consul APIG TCP Listener:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1667/ui/"
    echo -e ""
    echo -e "${GRN}Paris App UI addresses (Permissive Mode): ${NC}"
    echo -e " ${YELL}Pretty-Please:${NC} $DC3_P1_PARIS_PLEASE_ADDR"
    echo -e " ${YELL}Leroy-Jenkins:${NC} $DC3_P1_PARIS_LEROY_ADDR"
    echo ""
    echo -e "${GRN}BananaSplit App UI addresses (Service Splitting): ${NC}"
    echo -e " ${YELL}Neapolitan:${NC} $DC3_P1_NEAPOLITAN_ADDR"
fi

# ----------------------------------------------
#                  Footer
# ----------------------------------------------
echo -e "${RED}Happy Consul'ing! ${NC}"
echo -e ""

if $ARG_EKSONLY; then
  echo -e "Before running ${YELL}terraform destroy${NC}, first run ${YELL}./kill.sh -eks${NC} to prevent AWS from horking. Trust me."
  echo ""
fi