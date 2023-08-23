# HashiCorp "Doctor" Consul Environment

This repo contains a full featured environment for setting up and testing HashiCorp Consul Enterprise. While it is not directly intended to be used for Consul demos, the local environment (docker-compose + k3d) is consistently built in <10 minutes.

**Details**:

* Heavy focus on implementing and testing the latest Consul features.
* Rapidly changing, constant work-in-progress.
* [Doctor Consul Helper](https://github.com/joshwolfer/doctorconsul-helper) tool for easily collecting troubleshooting data.
* Environment contains both Kubernetes (AWS EKS or K3d) as well as VM style agents (docker-compose).
  * Do not have to run the entire environment. Can choose between the full environment, just Kube, or just VM style.

**Software Versions used in this environment**:

* Consul: 1.16.0 (Enterprise)
* Envoy: 1.25.1
* FakeService: 0.25.0
* Prometheus: 2.42.0

#### Consul Features

* Consul Enterprise
* Admin Partitions Enabled
* Best-Practice Security Features Enabled
  * TLS encryption on all nodes.
  * TLS Verify on everything.
  * Gossip Encryption enabled.
* UI Visualizations turned on for all mesh applications.
  * Prometheus servers:
    * kube: prometheus-server
    * docker: prometheus
* PKI / Certificates
  * Auto encrypt enabled (automatic distribution of Consul Client RPC certificates)
* ACLs enabled w/ tokens and policies applied.
* External OIDC Authentication:
  * OIDC enabled with Auth0 service.

# Environment Pre-Requirements

### HashiCorp Consul Enterprise

* HashiCorp Consul Enterprise license required.
  * Place in `./license`
* The `consul` enterprise binary must installed and in the PATH.
* (VM-style only): Generate Consul PKI Root certs and Consul Server RPC certs
  * Self-signed certificates have already been provided in this repo.
  * If they need to be regenerated:
    * From within `./certs`
      ```
      consul tls ca create -days=3650
      consul tls cert create -server -dc=dc1 -additional-dnsname=consul-server1-dc1 -days=1825
      consul tls cert create -server -dc=dc2 -additional-dnsname=consul-server1-dc2 -days=1825
      chmod 644 *
      ```

### Auth0 (Optional)

* Create Auth0 account with appropriate configuration
  * Required only for the OIDC authentication in this Consul environment.
  * Details on how to do that will come later. For now reference this [Learn Guide](https://developer.hashicorp.com/consul/tutorials/datacenter-operations/single-sign-on-auth0?in=consul%2Fdatacenter-operations).
    * NOTE: The guide is outdated and Auth0 has since changed the locations for a few of the components. Everything is still possible to complete using this guide, but the locations of the config params are in different places on the leftside bar. Specifically:
      * `Applications` > `Applications` > Default
      * `Auth Pipeline` > `Rules`

### Docker Compose (For VM style)

* The VM-style Environment requires Docker-Compose
  * **!! MAC M1 USERS !!** : The Docker images referenced in the `docker-compose.yml` are AMD64, not ARM64.
  * M1 user will need to build your own ARM64 consul+envoy images using [https://github.com/joshwolfer/convoy-build](https://github.com/joshwolfer/convoy-build) and modify the `docker-compose.yml` file to reflect these new images.

### K3d (For local Kube)

* K3d is a dockerized version of K3s, which is a simple version of Rancher Kubernetes.
* K3d can be used for the local Kubernetes portion of this environment.
* Installation instructions [HERE](https://github.com/k3d-io/k3d#get)

### Kubectl

* Installation instructions [HERE](https://kubernetes.io/docs/tasks/tools/)

### Helm

* Helm is used to configure and install Consul into Kubernetes.
* Installation instructions [HERE](https://helm.sh/docs/intro/install/)

### k9s (Optional)

* Highly recommended to get k9s to make navigating Kubernetes a lot easier.
* [https://github.com/derailed/k9s/releases](https://github.com/derailed/k9s/releases)

### AWS EKS + Terraform (Optional: Cloud Kubernetes)

* Doctor Consul Supports using 4 AWS EKS clusters
  * This is an alternative to using k3d locally.
  * Requires using Terraform + [https://github.com/ramramhariram/EKSonly](https://github.com/ramramhariram/EKSonly) to provision the EKS clusters
  * See specific "EKSOnly" instructions below.
  * Requires:
    * AWS CLI version 2 [HERE](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    * Terraform OSS [HERE](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

### HashiCorp consul-k8s CLI

* Installation instructions [HERE](https://developer.hashicorp.com/consul/docs/k8s/installation/install-cli#install-the-latest-version)

# Instructions to Execute Environment

## VM-Style Environment

* The "Consul on VMs" environment, uses docker-compose to launch a bunch of containers that run Consul Servers (DC1, DC2), Consul Client agents, and applications.
* The VM-Style environment is NOT required.
  * Doctor Consul *CAN* be instructed to just build the Kubernetes portion of the environment.
  * If this is desired, skip to the Kubernetes directions below.

### VM-Style Startup Script

* Startup script (Cleans out previous containers, k3d clusters, and peering tokens)
  * `./start.sh`
  * `./start.sh -root`
  * `./start.sh -custom`

The start script has three modes. By default the environment will assign Consul ACL tokens to most of the agents and proxies using the principle of least privilege (secure mode).

For more details, see the ACL docs.

### Configuration Script

* Once the start script has finished, the VM-style environment must be configured.
* Configure the core environment using the `post-config.sh` script:
  * `./post-config.sh`
  * `./post-config.sh -k3d`

The `-k3d` argument automatically runs `kube-config.sh -k3d-full` at completion.

* This builds the local Kubernetes environment using k3d AND cluster peers the VM-style environment to the local Kube environment.

## Kubernetes Environment

### Kube configuration script (k3d local)

* Build the K3d Kubernetes cluster using the `kube-config.sh` script:
  * `./kube-config.sh` : Default Builds ONLY the k3d environment
  * `./kube-config.sh -k3d-full` : Integrates k3d Kube clusters with the full VM-style environment.

The kube-config on it's own has no reliance on the VM-style environment, meaning you can simply just run `./kube-config.sh` and build a working 4 cluster configuration of Consul in k3d locally.

### Kube configuration script (AWS EKS "EKSOnly")

* Instead of building Kubernetes clusters locally using k3d, Doctor Consul can install and configure Consul into 4 pre-existing AWS EKS clusters using the [EKSOnly](https://github.com/ramramhariram/EKSonly) repo.
* The EKS clusters must be build in `us-east-1`.
  * If a different region is used, the additional SANS HELM config will need to be updated to reflect the correct region.
* This script will automatically map the Doctor Consul config to the the EKSOnly clusters using the following mapping:
  * KDC3 > nEKS0
  * KDC3_P1 > nEKS1
  * KDC4 > nEKS2
  * KDC4_P1 > nEKS3
* Build the K3d Kubernetes cluster using the `kube-config.sh` script:
  * `./kube-config.sh -eksonly` : Builds Consul into 4 clusters that have previously been created using [EKSOnly](https://github.com/ramramhariram/EKSonly).

The kube-config on it's own has no reliance on the VM-style environment, meaning you can simply just run `./kube-config.sh -eksonly` and build a working 4 cluster configuration of Consul in AWS EKS.

Be sure to follow the instructions completely in [EKSOnly](https://github.com/ramramhariram/EKSonly) building a 4 cluster setup.

# Delete Environment

## VM Style (docker-compose)

When the docker-compose windows is sent control+c, most of the docker images will shutdown. The Kube environment continues to run.

## Kubernetes Environment

### Kube (k3d)

Run the kill script to destroy varying levels of things:

* `./kill.sh` : Destroys all docker containers including k3d, except for the k3d image registry
* `./kill.sh -all` : Destroys all containers, including the registry. Nuke from orbit.

I recommend leaving the registry intact, since it takes time to re-cache the images and the registry doesn't consume much in resources just sitting there. Also, if you pull too many images from dockerhub in a single day, you'll get cut off (the reason the registry was configured in the first place).

### Kube (AWS EKS "EKSOnly")

Run the kill script with the following option:

* `./kill.sh -eksonly` : Deletes components out of the Kube environment preparring it for a `terraform destroy`.

NOTE: The kill script does NOT delete the EKS clusters or other infrastructure provisioned by Terraform in the EKSOnly repo. If you do not first run `./kill.sh -eksonly`, a terraform delete will hang when it attempts to delete everything from AWS and you'll have to manually delete loadbalancers and EINs associated with the EKS clusters that are orphaned by Terraform.

TLDR; run `./kill.sh -eksonly` and THEN run `terraform destroy` and all will be right in the world.

IMPORTANT: The EKSOnly environment can only be built once by the `./kube-config -eksonly` script. There are orphaned resources left over by the `./kill.sh` script. I'm looking to have an option to completely clean up the EKS clusters so the `./kube-config -eksonly` script can be run additional times without having to rebuild the EKS clusters with terraform, but it's not there yet. Yay Devops'ing.

# Documentation

The Doctor Consul architecture (including visual diagram) and details are [HERE](docs/architecture.md)

### Consul Specifics:

* Network Overview and Chart: [HERE](docs/network.md)
* Admin Partitions, Namespaces, & Cluster Peering Details: [HERE](docs/consul-structure.md)
* Consul Client Details: [HERE](docs/consul-clients.md)
* ACL Authentication, Policies, Roles, and ACL Tokens: [HERE](docs/acl-everything.md)
* UI Visualizations (Prometheus): [HERE](docs/ui-viz.md)

### Zork Control Script

The `./zork.sh` script is a menu driven system to control various aspects of the Doctor Consul environment.
Docs: [HERE](docs/zork.md)

### Doctor Consul Applications

Several "fake service" applications are deployed in the Doctor Consul environment. These applications are used to demonstrate and observe various Consul service mesh behaviors, such as advanced routing and service failover.

Docs: [HERE](docs/fake-service.md)

# Future Goals

### Key Architecture

* Add ECS cluster
  * Need to figure out how to expose local networking to ECS. This may not be practical for a DC lab. We'll see.
* Find someone that is a Terraform boss and launch an HCP cluster with integration.
* Add AWS Lambda connected via Consul Terminating Gateway.

### PKI / Certificates

HashiCorp Vault will eventually be implemented in the future as the Certificate Authority for the Consul Connect Service Mesh.

* The Vault server is currently commented out in the docker-compose file.
* Add Vault as the ConnectCA
* Use a unique CA keyset for each DC (`DC1` / `DC2`)
  * This is how separately managed clusters would work in the real world.

### Authentication Methods

* Add JWT authentication

### Transparent Proxy on VM and Kube

* Add some transparent proxies + fake service.

### Requests from the field

* Consul API Gateway
* Vault as TLS CA in one of the clusters.
* README's for each application and it's uses.
