# ACL Auth / Policies / Roles / Tokens

## ACL Tokens

Envoy side-car ACLs are controlled via the `start.sh` script. The ACL tokens listed below will only be accurate when running in the default "secure" mode.

#### Token: `root`

* Policy: `global-management`


| Token                                  | Privs                                                                                                                                         | Purpose                                                      |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `00000000-0000-0000-0000-000000001111` | node-identity:`client-dc1-alpha:dc1`,service-identity:`joshs-obnoxiously-long-service-name-gonna-take-awhile:dc1`,service-identity:`josh:dc1` | Agent token for Consul Client`consul-client-dc1-alpha` (DC1) |
| `00000000-0000-0000-0000-000000002222` | Role:`team-proj1-rw`                                                                                                                          | Grant write permissions within`DC1` / `proj1` partition.     |
| `00000000-0000-0000-0000-000000003333` | Role:`DC1-Read`                                                                                                                               | Read-only privileges within the entire`DC1` cluster.         |
| `00000000-0000-0000-0000-000000004444` | service-identy:`unicorn.frontend.unicorn-frontend:dc1`                                                                                        |                                                              |
| `00000000-0000-0000-0000-000000005555` | service-identity:`unicorn.backend.unicorn-backend:dc1`                                                                                        |                                                              |
| `00000000-0000-0000-0000-000000006666` | service-identity:`unicorn.backend.unicorn-backend:dc2`                                                                                        |                                                              |
| `00000000-0000-0000-0000-000000007777` | service-identity:`default.default.web:dc1`                                                                                                    |                                                              |
| `00000000-0000-0000-0000-000000008888` | service-identity:`default.default.web-upstream:dc1`                                                                                           |                                                              |
| `00000000-0000-0000-0000-000000009999` | service-identity:`chunky.default.web-chunky:dc2`                                                                                              |                                                              |

## Roles

#### Role: `consul-admins`

* Policy: `global-management`
* Purpose:
  * Assign root level permissions.
  * Used within the Auth0 OIDC method (group: `admins`) to define who should have "god mode" in the Consul Cluster

#### Role: `team-proj1-rw`

* Purpose: Grant write permissions within `DC1` / `proj1` partition.
* Used within the Auth0 OIDC method (group: `proj1`) to define who should have management permission of the `proj` partition

#### Role: `dc1-read`

* Purpose: Read-only privileges within the entire `DC1` cluster.

## OIDC Authentiction

### Auth0

#### Binding Rules

* auth0 groups = `proj1`
* auth0 groups = `admins`