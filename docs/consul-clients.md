## Consul Clients

Tokens for Clients are written directly to agent config files (cannot be changed).

### consul-client-dc1-alpha (DC1)

* **DC**: `DC1`
* **Partition**: `default`
* **Services**:
  * `josh` (4 instances)
    * This `josh` service is exported to the `DC2` peer (`default`).
    * The `service.id` is `josh-local-x` to differentiate between this local service and the imported service (see Notes below)
  * `joshs-obnoxiously-long-service-name-gonna-take-awhile` (8 instances)
    * This `joshs-obnoxiously-long-service-name-gonna-take-awhile` service is exported to the `DC2` peer (`default`).
* **ACL Token**: `00000000-0000-0000-0000-000000001111`
  * `node-identity=client-dc1-alpha:dc1`
  * `service-identity=joshs-obnoxiously-long-service-name-gonna-take-awhile:dc1`
  * `service-identity=josh:dc1`
* **Notes**:
  * Within `DC1` and `DC2`, each cluster contains a service named `josh`.
  * This is intentional, as to test out the behavior of when a exported service from a peer matches the same name of a local service.
  * `DC1/default_AP/default_NS/josh` and `DC2/default_AP/default_NS/josh => DC1/default_AP/default_NS`
  * (Bug) As of 1.13.2, the UI cannot list the instances of both `josh` services by clicking on them.
    * Both links point to the imported `josh` only (bugged)
    * The UI URL can be manually manipulated to view the local `josh`: `http://127.0.0.1:8500/ui/_default/dc1/services/josh/instances`

### consul-client-dc1-charlie-ap1 (DC1)

* **DC**: `DC1`
* **Partition**: `donkey`
* **Services**:
  * `donkey` (5 instances)
* **ACL Token**: `root`
* **Notes**:

### consul-client-dc1-unicorn (DC1)

* **DC**: `DC1`
* **Partition**: `unicorn`
* **Services**:
  * `unicorn-frontend` (3 instances)
    * Namespace: `frontend`
  * `unicorn-backend` (3 instances)
    * Namespace: `backend`
* **ACL Token**: `root`
* **Notes**:

### consul-client-dc1-echo-proj1 (DC1)

* **DC**: `DC1`
* **Partition**: `proj1`
* **Services**
  * `baphomet` (3 instances)
* **ACL Token**: `root`
* **Notes**:

### virtual (DC1)

* **DC**: `DC1`
* **Partition**: `proj1`
* **Services**
  * `virtual-baphomet` (3 external instances)
* **Notes**:
  * This is a virtual node registered with the `post-config.sh` script.
  * It represents an externally registered service
  * Each `virtual-baphomet` service can be de-registered using the following commands:
    ```
    curl --request PUT --data @./configs/services-dc1-proj1-baphomet0.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
    curl --request PUT --data @./configs/services-dc1-proj1-baphomet1.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
    curl --request PUT --data @./configs/services-dc1-proj1-baphomet2.json --header "X-Consul-Token: root" localhost:8500/v1/catalog/register
    ```

### consul-client-dc2-bravo (DC2)

* **DC**: `DC2`
* **Partition**: `default`
* **Services**:
  * `josh` (7 instances)
* **ACL Token**: `root`
* **Notes**:
  * This `josh` service is exported to the `DC1` peer (`default`).

### consul-client-dc2-foxtrot (DC2)

* **DC**: `DC2`
* **Partition**: `chunky`
* **Services**:
  * `web-chunky` (in-mesh)
* **ACL Token**: `root`
* **Notes**: