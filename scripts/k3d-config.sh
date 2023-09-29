#!/bin/bash

set -e

# All the k3d stuff happens HERE onward

# ------------------------------------------
# Is Docker running? Start docker service if not
# ------------------------------------------

# service syntax to start docker differs between OSes. This checks if you're on Linux vs Mac.

OS_NAME=$(uname -a)

if [[ "$OS_NAME" == *"Linux"* ]]; then
    echo ""
    echo -e "${GRN}Checking that Docker is running - If not starting it. ${NC}"
    pgrep dockerd || sudo service docker start
    echo ""

    sleep 2
else
    # Eventually put in mac syntax to start docker, its not the same as linux
    echo ""
fi

# ------------------------------------------
# Clock / Date / Time Correct?
# ------------------------------------------

# Because WSL is pissing me off and the UI metrics grab from Prometheus breaks if the clock is out of sync.
# It'll also break provisioning TF and other AWS functions.
# Commenting this out. It might actually be fixed now that I've installed NTP into WSL2. /crossing fingers.

  # WSL=$(uname -a)

  # if [[ $WSL == *"WSL"* ]]; then
  #   echo -e "${GRN}syncing the WSL clock to hardware...${NC}"
  #   sudo hwclock -s
  # fi

# ------------------------------------------
#  Local DNS Hosts entry for k3d registry
# ------------------------------------------

set +e    # If we don't do this, the script will exit when there is nothing in the hosts file

OS_NAME=$(uname -a)

if [[ "$OS_NAME" == *"Linux"* ]];
  then
    # Match WSL2, since it handles DNS all weird like...
    echo "Linux Detected"

    HOSTS_EXISTS=$(grep "doctorconsul" /etc/hosts)

    if [[ -z "$HOSTS_EXISTS" ]];
      then   # If the grep returns nothing...
        echo -e "${YELL}k3d-doctorconsul.localhost does not exist (${GRN}Adding entry${NC})"
        echo "127.0.0.1       k3d-doctorconsul.localhost" | sudo tee -a /etc/hosts > /dev/null
        grep "doctorconsul" /etc/hosts
      else
        echo -e "${YELL}k3d-doctorconsul.localhost already exists (${RED}Skipping..${NC})"
    fi

    echo ""
  elif [[ "$OS_NAME" == *"Darwin"* ]];
    then
      # Match Darwin (Mac)
      echo "Mac Detected"

      HOSTS_EXISTS=$(grep "doctorconsul" /etc/hosts)

      if [[ -z "$HOSTS_EXISTS" ]];
        then   # If the grep returns nothing...
          echo -e "${YELL}k3d-doctorconsul.localhost does not exist (${GRN}Adding entry${NC})"
          echo "127.0.0.1       k3d-doctorconsul.localhost" | sudo tee -a /etc/hosts > /dev/null
          grep "doctorconsul" /etc/hosts
        else
          echo -e "${YELL}k3d-doctorconsul.localhost already exists (${RED}Skipping..${NC})"
      fi
    echo ""
  else
    echo "Neither Linux nor Mac detected (${RED}Skipping..${NC}"
fi

# ------------------------------------------
#     Does k3d registry already exist?
# ------------------------------------------

# Pulling images from docker hub repeatedly, will eventually get you rate limited :(
# This sets up a local registry so images can be pulled and cached locally.
# This is better in the long run anyway, beecause it'll save on time and bandwidth.

REGISTRY_EXISTS=$(k3d registry list | grep doctorconsul)

if [[ "$REGISTRY_EXISTS" == *"doctorconsul"* ]];
  then
    echo ""
    echo -e "${GRN}Checking if the k3d registry (doctorconsul) already exist${NC}"
    echo -e "${YELL}Registry exist (${RED}Skipping...${NC})"
    echo ""
  else
    k3d registry create doctorconsul.localhost --port 12345    # Creates the registry k3d-doctorconsul.localhost
fi

set -e    # Enabled exit on errors again.

# ------------------------------------------
#  Pull images and cache into the k3d registry
# ------------------------------------------

# Leaving these for posterity. Don't actually need to mirror the images, just cache the images locally and then import into k3d.
  # docker pull calico/cni:v3.15.0
  # docker tag calico/cni:v3.15.0 joshwolfer/calico-cni:v3.15.0
  # docker push joshwolfer/calico-cni:v3.15.0

  # docker pull calico/pod2daemon-flexvol:v3.15.0
  # docker tag calico/pod2daemon-flexvol:v3.15.0 joshwolfer/calico-pod2daemon-flexvol:v3.15.0
  # docker push joshwolfer/calico-pod2daemon-flexvol:v3.15.0

  # docker pull calico/node:v3.15.0
  # docker tag calico/node:v3.15.0 joshwolfer/calico-node:v3.15.0
  # docker push joshwolfer/calico-node:v3.15.0

IMAGE_CALICO_CNI="calico/cni:v3.15.0"
IMAGE_CALICO_FLEXVOL="calico/pod2daemon-flexvol:v3.15.0"
IMAGE_CALICO_NODE="calico/node:v3.15.0"
IMAGE_CALICO_CONTROLLER="calico/kube-controllers:v3.15.0"
IMAGE_FAKESERVICE="nicholasjackson/fake-service:v0.26.0"

echo -e "${GRN}Caching docker images locally${NC}"

# Pull the public images, tag them for the k3d registry, and push them into the k3d registry
# Probably going to have to add all the Consul images in there as well - only a matter of time before Docker Hub gets mad about those.
# Will add them when k8s starts getting Image pull errors again ;)

docker pull $IMAGE_CALICO_CNI
docker tag $IMAGE_CALICO_CNI k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CNI
docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CNI

docker pull $IMAGE_CALICO_FLEXVOL
docker tag $IMAGE_CALICO_FLEXVOL k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_FLEXVOL
docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_FLEXVOL

docker pull $IMAGE_CALICO_NODE
docker tag $IMAGE_CALICO_NODE k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_NODE
docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_NODE

docker pull $IMAGE_CALICO_CONTROLLER
docker tag $IMAGE_CALICO_CONTROLLER k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CONTROLLER
docker push k3d-doctorconsul.localhost:12345/$IMAGE_CALICO_CONTROLLER

docker pull $IMAGE_FAKESERVICE
docker tag $IMAGE_FAKESERVICE k3d-doctorconsul.localhost:12345/$IMAGE_FAKESERVICE
docker push k3d-doctorconsul.localhost:12345/$IMAGE_FAKESERVICE


# ==========================================
#             Setup K3d clusters
# ==========================================

# echo -e "${GRN}"
# echo -e "------------------------------------------"
# echo -e " Download Calico Config files"
# echo -e "------------------------------------------${NC}"

# Fetch the Calico setup file to use with k3d.
# K3D default CNI (flannel) doesn't work with Consul Tproxy / DNS proxy

# curl -s https://k3d.io/v5.0.1/usage/advanced/calico.yaml -o ./kube/calico.yaml
# ^^^ Don't downloading again. the image locations have been changed to the local k3d registry.

# ------------------------------------------
#                    DC4
# ------------------------------------------

(k3d cluster create dc3 --network doctorconsul_wan \
    --api-port 127.0.0.1:6443 \
    -p "8502:443@loadbalancer" \
    -p "11000:8000" \
    -p "11001:8001" \
    -p "9091:9090" \
    -p "1666:1666" \
    -p "1667:1667" \
    -p "8002:8002" \
    -p "8003:8003" \
    --k3s-arg '--flannel-backend=none@server:*' \
    --registry-use k3d-doctorconsul.localhost:12345 \
    --k3s-arg="--disable=traefik@server:0" && \
kubectl apply --context=$KDC3 -f ./kube/calico.yaml) &

    # -p "11000:8000"    DC3/unicorn/unicorn-frontend (fake service UI)     - Mapped to local http://127.0.0.1:11000/ui/
    # -p "11001:8001"    DC3/unicorn/unicorn-ssg-frontend (fake service UI) - Mapped to local http://127.0.0.1:11001/ui/
    # -p "9091:9090"     Prometheus UI
    # -p "1666:1666"     Consul APIG HTTP Listener
    # -p "1666:1666"     Consul APIG TCP Listener
    # -p "8002:8002"     DC3/externalz/Externalz-tcp UI - Mapped to local http://127.0.0.1:8002/ui/
    # -p "8003:8003"     DC3/externalz/Externalz-http UI - Mapped to local http://127.0.0.1:8003/ui/

    # Disable flannel
    # install Calico (tproxy compatability)

# ------------------------------------------
#              DC3 cernunnos
# ------------------------------------------

(k3d cluster create dc3-p1 --network doctorconsul_wan \
    --api-port 127.0.0.1:6444 \
    -p "8443:8443" \
    -p "8100:8100" \
    -p "8101:8101" \
    -p "8007:8007" \
    --k3s-arg="--disable=traefik@server:0" \
    --registry-use k3d-doctorconsul.localhost:12345 \
    --k3s-arg '--flannel-backend=none@server:*' && \
kubectl apply --context=$KDC3_P1 -f ./kube/calico.yaml) &

    # -p "8443:8443"      api-gateway ingress
    # -p "12000:8000"     reserved for fakeservice something
    # -p "8100:8100"      paris/pretty-please UI
    # -p "8101:8101"      paris/leroy-jenkins UI
    # -p "8007:8007"      banana-split/neapolitan 

# ------------------------------------------
#                   DC4
# ------------------------------------------

(k3d cluster create dc4 --network doctorconsul_wan \
    --api-port 127.0.0.1:6445 \
    -p "8503:443@loadbalancer" \
    -p "8200:8200@loadbalancer" \
    -p "12000:8000" \
    -p "9092:9090" \
    -p "8004:8004" \
    -p "8005:8005" \
    -p "8006:8006" \
    --k3s-arg '--flannel-backend=none@server:*' \
    --registry-use k3d-doctorconsul.localhost:12345 \
    --k3s-arg="--disable=traefik@server:0" && \
kubectl apply --context=$KDC4 -f ./kube/calico.yaml) &

#  12000 > 8000 - whatever app UI
#  local 8503 > 443 - Consul UI
#  8200 > 8200 - Vault API
    # -p "8004:8004" sheol-app
    # -p "8005:8005" sheol-app1
    # -p "8006:8006" sheol-app2

# ------------------------------------------
#            DC4-P1 taranis
# ------------------------------------------

(k3d cluster create dc4-p1 --network doctorconsul_wan \
    --api-port 127.0.0.1:6446 \
    --k3s-arg="--disable=traefik@server:0" \
    --registry-use k3d-doctorconsul.localhost:12345 \
    --k3s-arg '--flannel-backend=none@server:*' && \
kubectl apply --context=$KDC4_P1 -f ./kube/calico.yaml) &

# Wait for all background jobs to finish
wait

sleep 3    # See if kube context missing error goes away.