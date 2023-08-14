#!/bin/bash

set -e

# ==============================================================================================================================
#                                                      Outputs
# ==============================================================================================================================

if $ARG_EKSONLY;
  then
    export UNICORN_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')
    # export UNICORN_SSG_FRONTEND_UI_ADDR=$(kubectl get svc unicorn-ssg-frontend -nunicorn --context $KDC3 -o json | jq -r '"http://\(.status.loadBalancer.ingress[0].hostname):\(.spec.ports[0].port)"')

    # ------------------------------------------
    #  Wait and Discover SSG Unicorn LB
    # ------------------------------------------

    while true; do    
      SSG_HOSTNAME=$(kubectl get svc unicorn-ssg-frontend -n unicorn --context $KDC3 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      SSG_PORT=$(kubectl get svc unicorn-ssg-frontend -n unicorn --context $KDC3 -o jsonpath='{.spec.ports[0].port}')

      if [ ! -z "$SSG_HOSTNAME" ]; then
        UNICORN_SSG_FRONTEND_UI_ADDR=http://$SSG_HOSTNAME:$SSG_PORT/ui/
        break
      fi

      echo "Waiting for the SSG load balancer to get an ingress hostname..."
      sleep 2
    done

    # ------------------------------------------
    #  Wait and Discover Externalz TCP LB
    # ------------------------------------------

    while true; do
      DC3_EXTERNALZ_TCP_HOSTNAME=$(kubectl get svc externalz-tcp -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')

      if [ ! -z "$DC3_EXTERNALZ_TCP_HOSTNAME" ]; then
        DC3_EXTERNALZ_TCP_ADDR=http://$DC3_EXTERNALZ_TCP_HOSTNAME:8002/ui/
        break
      fi

      echo "Waiting for the externalz-tcp load balancer to get an ingress hostname..."
      sleep 2
    done

    # ------------------------------------------
    #  Wait and Discover Externalz HTTP LB
    # ------------------------------------------

    while true; do
      DC3_EXTERNALZ_HTTP_HOSTNAME=$(kubectl get svc externalz-http -nexternalz --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')

      if [ ! -z "$DC3_EXTERNALZ_HTTP_HOSTNAME" ]; then
        DC3_EXTERNALZ_HTTP_ADDR=http://$DC3_EXTERNALZ_HTTP_HOSTNAME:8003/ui/
        break
      fi

      echo "Waiting for the externalz-http load balancer to get an ingress hostname..."
      sleep 2
    done

    while true; do
        DC3_CONSUL_API_GATEWAY_HOSTNAME=$(kubectl get svc consul-api-gateway -nconsul --context $KDC3 -o json | jq -r '.status.loadBalancer.ingress[0].hostname')

        if [ ! -z "$DC3_CONSUL_API_GATEWAY_HOSTNAME" ]; then
            DC3_CONSUL_API_GATEWAY_ADDR=http://$DC3_CONSUL_API_GATEWAY_HOSTNAME
            break
        fi

        echo "Waiting for the consul-api-gateway load balancer to get an ingress hostname..."
        sleep 2
    done

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

${GRN}Consul API-GW LB Address: ${NC}
 ${YELL}Consul APIG HTTP Listener:${NC} http://127.0.0.1:1666"
 ${YELL}Consul APIG TCP Listener:${NC} http://127.0.0.1:1667"

${GRN}Export ENV Variables ${NC}
 export DC3=https://127.0.0.1:8502
 export DC4=https://127.0.0.1:8503
EOF
)"

fi