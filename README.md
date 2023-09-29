# HashiCorp "Doctor" Consul Environment

This repo contains a full featured environment for setting up and testing HashiCorp Consul Enterprise. While it is not directly intended to be used for Consul demos, the local environment (docker-compose + k3d) is consistently built in <10 minutes.

NOTE!: The proper Doctor Consul manual (PDF) is located [HERE](docs/DoctorConsul-TheManual-Draft.pdf).

ALL of the Kube side docs have been moved there. Go read it!!
It is a far better way of consuming this information than this README.md.
Currently it only covers the Kubernetes side of Doctor Consul, not the VM-based side.
I'm phasing out this README. Until then, consult this READMe for the VM (DC1 / DC2) side and the PDF for the Kube (DC3 / DC4) side.

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

### Auth0 (Optional)* Create Auth0 account with appropriate configuration

* Required only for the OIDC authentication in this Consul environment.
* Details on how to do that will come later. For now reference this [Learn Guide](https://developer.hashicorp.com/consul/tutorials/datacenter-operations/single-sign-on-auth0?in=consul%2Fdatacenter-operations).
  * NOTE: The guide is outdated and Auth0 has since changed the locations for a few of the components. Everything is still possible to complete using this guide, but the locations of the config params are in different places on the leftside bar. Specifically:
    * `Applications` > `Applications` > Default
    * `Auth Pipeline` > `Rules`

### Docker Compose (For VM style)

* The VM-style Environment requires Docker-Compose
  * **!! MAC M1 USERS !!** : The Docker images referenced in the `docker-compose.yml` are AMD64, not ARM64.
  * M1 user will need to build your own ARM64 consul+envoy images using [https://github.com/joshwolfer/convoy-build](https://github.com/joshwolfer/convoy-build) and modify the `docker-compose.yml` file to reflect these new images.

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
* Open a different shell (leave the `start.sh` script running) and configure the core environment using the `post-config.sh` script:
  * `./post-config.sh`
  * `./post-config.sh -k3d`

The `-k3d` argument automatically runs `kube-config.sh -k3d-full` at completion.

* This builds the local Kubernetes environment using k3d AND cluster peers the VM-style environment to the local Kube environment.

# Delete Environment

## VM Style (docker-compose)

When the docker-compose windows is sent control+c, most of the docker images will shutdown. The Kube environment continues to run.

# Documentation

The Doctor Consul architecture (including visual diagram) and details are [HERE](docs/architecture.md)

### Consul Specifics:

* Network Overview and Chart: [HERE](docs/network.md)
* Admin Partitions, Namespaces, & Cluster Peering Details: [HERE](docs/consul-structure.md)
* Consul Client Details: [HERE](docs/consul-clients.md)
* ACL Authentication, Policies, Roles, and ACL Tokens: [HERE](docs/acl-everything.md)
* UI Visualizations (Prometheus): [HERE](docs/ui-viz.md)

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

* Vault as TLS CA in one of the clusters.
