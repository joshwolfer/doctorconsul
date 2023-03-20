# Zork Environment Control Script

The `./zork.sh` script is a menu driven system to control various aspects of the environment.

This is to make it as easy as possible on the operator of Doctor Consul, so the most common tasks can be accomplished without requiring in depth knowledge of the environment or Consul.

The most noteworthy is to kill and restore containers in the "Unicorn" application. This makes it so you do not have to copy, paste, or memorize commands to make full-use of the Doctor Consul environment.

## Contents

* **Service Discovery**

  * DC1/donkey/donkey (local AP export)
    * API Discovery (health + catalog endpoints)
* **Manipulate Services**

  * Register Virtual-Baphomet
  * De-register Virtual-Baphomet Node
* **Unicorn Demo**

  * Nuke Unicorn-Backend (DC1) Container
  * Restart Unicorn-Backend (DC1) Container (root token)
  * Restart Unicorn-Backend (DC1) Container (standard token)
  * Nuke Unicorn-Backend (DC2) Container
  * Restart Unicorn-Backend (DC2) Container (root token)
  * Restart Unicorn-Backend (DC2) Container (standard token)
* **Kubernetes**

  * Get DC3 LoadBalancer Address
  * Kube Apply DC3/unicorn-frontend
  * Kube Delete DC3/unicorn-frontend
  * Kube Apply DC3/unicorn-backend
  * Kube Delete DC3/unicorn-backend
* **Docker Compose**

  * Reload Docker Compose (Root Tokens)
  * Reload Docker Compose (Secure Tokens)
  * Reload Docker Compose (Custom Tokens)
* **Else**

  * API call template to Consul Servers
  * Stream logs from Consul Servers
