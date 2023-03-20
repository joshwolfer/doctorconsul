## Admin Partitions & Namespaces

### DC1

* `default`
* `donkey`
* `unicorn`
  * `frontend` (NS)
  * `backend` (NS)
* `proj1`
* `proj2`

### DC2

* `default`
* `heimdall`
* `unicorn`
  * `frontend` (NS)
  * `backend` (NS)

### DC3 (k3d)

* `default`
  * `unicorn` (NS)

## Cluster Peering Relationships & Exported Services

### Configuration

* Cluster Peering over Mesh Gateways enabled

### Peering Relationships

* `DC1`/`default` <- `DC2`/`default`
* `DC1`/`default` <- `DC2`/`heimdall`
* `DC1`/`default` -> `DC2`/`chunky`
* `DC1`/`unicorn` <- `DC2`/`unicorn`
* `DC3`/`default` -> `DC1`/`default`
* `DC3`/`default` -> `DC1`/`unicorn`
* `DC3`/`default` -> `DC2`/`unicorn`

### Exported Services

#### DC1

* `DC1`/`donkey(AP)/donkey` > `DC1`/`default(AP)` (local partition)
* `DC1`/`default(AP)/joshs-obnoxiously-long-service-name-gonna-take-awhile`>`DC2`/`default(AP)` (Peer)
* `DC1`/`default(AP)/joshs-obnoxiously-long-service-name-gonna-take-awhile`>`DC2`/`heimdall(AP)` (Peer)

#### DC2

* `DC2`/`default(AP)/josh`>`DC1`/`default` (Peer)
* `DC2`/`unicorn(AP)/unicorn-backend` > `DC1`/`unicorn` (Peer)

#### DC3

* `DC3`/`default(AP)/unicorn(NS)/unicorn-backend` > `DC1`/`unicorn` (peer)