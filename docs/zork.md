The `./zork.sh` script is a menu driven system to control various aspects of the environment. The most noteworthy is to kill and restore containers in the "Unicorn" application. This makes it so you do not have to copy and paste or memorize lots of commands to make full use of Doctor Consul.

Framework

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
