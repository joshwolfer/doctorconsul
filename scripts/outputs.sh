#!/bin/bash

set -e

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

if $ARG_NO_APPS;
  then

echo -e "$(cat << EOF
${RED} Consul is installed. Exiting before applications are installed! ${NC}

${GRN}
------------------------------------------
  No Installed Apps (Kube Clusters only)
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: http://$DC3_LB_IP:8500
 ${YELL}DC4${NC}: http://$DC4_LB_IP:8500

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Export ENV Variables ${NC}
 export DC3=http://$DC3_LB_IP:8500
 export DC4=http://$DC4_LB_IP:8500

 KDC3=k3d-dc3
 KDC3_P1=k3d-dc3-p1
 KDC4=k3d-dc4
 KDC4_P1=k3d-dc4-p1

${GRN}Port forwards to map UI to traditional Doctor Consul local ports: ${NC}
 kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &
 kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &

${RED}Happy Consul'ing!!! ${NC}

Before running ${YELL}terraform destroy${NC}, first run ${YELL}./kill.sh -eksonly${NC} to prevent AWS from horking. Trust me.

You can now start manually provisioning the applications in the kube-config.sh starting at line: $(grep -n "Install Unicorn Application" ./kube-config.sh | cut -f1 -d: | awk 'NR==2')
EOF
)"

exit 0

fi

if $ARG_EKSONLY;
  then
    export UNICORN_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')
    # export UNICORN_SSG_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')

    # # ------------------------------------------
    # #  (DC3) Wait and Consul API GW
    # # ------------------------------------------

    # APIG has two ports, can't use the wait_for_service() function

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
    wait_for_service() {
      local svc_name=$1
      local namespace=$2
      local context=$3
      local max_retries=$4
      local port_suffix=$5
      local counter=0
      local hostname_var_name=$6
      local addr_var_name=$7

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
    wait_for_service "unicorn-ssg-frontend" "unicorn" "$KDC3" 6 "/ui/" "SSG_HOSTNAME" "UNICORN_SSG_FRONTEND_UI_ADDR"
    wait_for_service "externalz-tcp" "externalz" "$KDC3" 6 "/ui/" "DC3_EXTERNALZ_TCP_HOSTNAME" "DC3_EXTERNALZ_TCP_ADDR"
    wait_for_service "externalz-http" "externalz" "$KDC3" 6 "/ui/" "DC3_EXTERNALZ_HTTP_HOSTNAME" "DC3_EXTERNALZ_HTTP_ADDR"
    wait_for_service "sheol-app" "sheol" "$KDC4" 6 "/ui/" "DC4_SHEOL_HOSTNAME" "DC4_SHEOL_ADDR"
    wait_for_service "sheol-app1" "sheol-app1" "$KDC4" 6 "/ui/" "DC4_SHEOL1_HOSTNAME" "DC4_SHEOL1_ADDR"
    wait_for_service "sheol-app2" "sheol-app2" "$KDC4" 6 "/ui/" "DC4_SHEOL2_HOSTNAME" "DC4_SHEOL2_ADDR"
    # wait_for_service "consul-api-gateway" "consul" "$KDC3" 6 "" "DC3_CONSUL_API_GATEWAY_HOSTNAME" "DC3_CONSUL_API_GATEWAY_ADDR"    # APIG has two ports, can't use this function for now


# ------------------------------------------------------------------------------------
#                                 EKSOnly Outputs
# ------------------------------------------------------------------------------------

echo -e "$(cat << EOF
${GRN}
------------------------------------------
            EKSOnly Outputs
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: http://$DC3_LB_IP:8500
 ${YELL}DC4${NC}: http://$DC4_LB_IP:8500

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Fake Service UI addresses: ${NC}
 ${YELL}Unicorn-Frontend:${NC} $UNICORN_FRONTEND_UI_ADDR/ui/
 ${YELL}Unicorn-SSG-Frontend:${NC} $UNICORN_SSG_FRONTEND_UI_ADDR

${GRN}Externalz-tcp UI address: ${NC}
 ${YELL}Externalz-tcp:${NC} $DC3_EXTERNALZ_TCP_ADDR
 ${YELL}Externalz-tcp:${NC} $DC3_EXTERNALZ_HTTP_ADDR

${GRN}Sheol App UI addresses: ${NC}
 ${YELL}Sheol-App:${NC} $DC4_SHEOL_ADDR
 ${YELL}Sheol-App1:${NC} $DC4_SHEOL1_ADDR
 ${YELL}Sheol-App2:${NC} $DC4_SHEOL2_ADDR

${GRN}Consul API-GW LB Address: ${NC}
 ${YELL}Consul APIG HTTP Listener:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1666"
 ${YELL}Consul APIG TCP Listener:${NC} $DC3_CONSUL_API_GATEWAY_ADDR:1667"

${GRN}Export ENV Variables ${NC}
 export DC3=http://$DC3_LB_IP:8500
 export DC4=http://$DC4_LB_IP:8500

${GRN}Port forwards to map services / UI to traditional Doctor Consul local ports: ${NC}
 kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-frontend 11000:8000 > /dev/null 2>&1 &
 kubectl -nunicorn --context $KDC3 port-forward svc/unicorn-ssg-frontend 11001:8001  > /dev/null 2>&1 &
 kubectl -n consul --context $KDC3 port-forward svc/consul-expose-servers 8502:8501 > /dev/null 2>&1 &
 kubectl -n consul --context $KDC4 port-forward svc/consul-expose-servers 8503:8501 > /dev/null 2>&1 &
 kubectl -nexternalz --context $KDC3 port-forward svc/externalz-tcp 8002:8002 > /dev/null 2>&1 &
 kubectl -nexternalz --context $KDC3 port-forward svc/externalz-http 8003:8003 > /dev/null 2>&1 &
 kubectl -nconsul --context $KDC3 port-forward svc/consul-api-gateway 1666:1666 > /dev/null 2>&1 &
 kubectl -nconsul --context $KDC3 port-forward svc/consul-api-gateway 1667:1667 > /dev/null 2>&1 &
 kubectl -nsheol --context $KDC4 port-forward svc/sheol-app 8004:8004 > /dev/null 2>&1 &
 kubectl -nsheol-app1 --context $KDC4 port-forward svc/sheol-app1 8005:8005 > /dev/null 2>&1 &
 kubectl -nsheol-app2 --context $KDC4 port-forward svc/sheol-app2 8006:8006 > /dev/null 2>&1 &

$(printf "${RED}"'Happy Consul'\''ing!!! '"${NC}\n")

Before running ${YELL}terraform destroy${NC}, first run ${YELL}./kill.sh -eksonly${NC} to prevent AWS from horking. Trust me.
EOF
)"

# If Unicorn-SSG-Frontend is blank - run do this. EKS is being slow and I need to build a check: kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r 'http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)'

  else

# ------------------------------------------------------------------------------------
#                                  Local K3D Outputs
# ------------------------------------------------------------------------------------

echo -e "$(cat << EOF
${GRN}------------------------------------------
            K3d Outputs
------------------------------------------${NC}

${GRN}Consul UI Addresses: ${NC}
 ${YELL}DC3${NC}: https://127.0.0.1:8502/ui/
 ${YELL}DC4${NC}: https://127.0.0.1:8503/ui/

${RED}Don't forget to login to the UI using token${NC}: 'root'

${GRN}Fake Service UI addresses: ${NC}
 ${YELL}Unicorn-Frontend:${NC} http://127.0.0.1:11000/ui/
 ${YELL}Unicorn-SSG-Frontend:${NC} http://localhost:11001/ui/
 ${YELL}Externalz-tcp:${NC} http://127.0.0.1:8002/ui/
 ${YELL}Externalz-http:${NC} http://127.0.0.1:8003/ui/
 ${YELL}(DC4) sheol-app:${NC} http://127.0.0.1:8004/ui/
 ${YELL}(DC4) sheol-app1:${NC} http://127.0.0.1:8005/ui/
 ${YELL}(DC4) sheol-app2:${NC} http://127.0.0.1:8006/ui/

${GRN}Consul API-GW LB Address: ${NC}
 ${YELL}Consul APIG HTTP Listener:${NC} http://127.0.0.1:1666"
 ${YELL}Consul APIG TCP Listener:${NC} http://127.0.0.1:1667"

${GRN}Export ENV Variables ${NC}
 export DC3=https://127.0.0.1:8502
 export DC4=https://127.0.0.1:8503
EOF
)"

fi