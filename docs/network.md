### Network Quick Chart

#### Shared Services

* Prometheus:
  * dc1 network: 10.5.0.200
    dc2 network: 10.6.0.200

#### (DC1) Consul Core

* DC1 server: 10.5.0.2 / 192.169.7.2
* DC1 MGW: 10.5.0.5 / 192.169.7.3
* DC1 MGW (unicorn): 10.5.0.6 / 192.169.7.7

#### (DC1) Consul Clients

* consul-client-dc1-alpha (default):        10.5.0.10
* consul-client-dc1-charlie-ap1 (donkey):   10.5.0.11
* consul-client-dc1-delta-ap2 (unicorn):    10.5.0.12
* consul-client-dc1-echo-proj1 (proj1):     10.5.0.13

#### (DC1) Applications

* web-v1:                         10.5.0.100
* web-upstream:                   10.5.0.101
* unicorn-frontend:               10.5.0.110
* unicorn-backend:                10.5.0.111

#### (DC2) Consul Core

* DC2 server:                          10.6.0.2 / 192.169.7.4
* DC2 MGW:                             10.6.0.5 / 192.169.7.5
* DC2 MGW (chunky):                    10.6.0.6 / 192.169.7.6
* DC2 MGW (unicorn):                   10.6.0.7 / 192.169.7.8

#### (DC2) Consul Clients

* consul-client-dc2-bravo   (default):      10.6.0.10
* consul-client-dc2-foxtrot (chunky):       10.6.0.11
* consul-client-dc2-unicorn (unicorn):      10.6.0.12

#### (DC2) Applications

* web-chunky:                               10.6.0.100
* unicorn-backend:                          10.6.0.111

#### (DC3) k3d

* consul (server)
* mesh-gateway
* unicorn-frontend (default)
* unicorn-backend (default)
* prometheus-server

### Local Listeners

* Consul Server1 DC1 UI: http://127.0.0.1:8500/ui/
* Consul Server1 DC2 UI: http://127.0.0.1:8501/ui/
* Consul Server DC3 UI: http://127.0.0.1:8502/ui/
* Web Service UI: http://127.0.0.1:9000/ui
* Unicorn-frontend (unicorn) DC1 UI: http://127.0.0.1:10000/ui
* Unicorn-frontend (default) DC3 UI: http://127.0.0.1:11000/ui
* Prometheus (non-kube) UI: http://localhost:9090/
* Prometheus (kube DC3) UI: http://localhost:9091/

#### Local Listeners for Envoy troubleshooting

* 19001: (dc1) gateway-dc1-unicorn
* 19002: (dc1) web
* 19003: (dc1) web-upstream
* 19004: (dc1) unicorn-frontend
* 19005: (dc1) unicorn-backend-dc1
* 19006: (dc1) gateway-dc1
* 19007: (dc2) gateway-dc2
* 19008: (dc2) gateway-dc2-chunky
* 19009: (dc2) gateway-dc2-unicorn
* 19010: (dc2) web-chunky
* 19011: (dc2) unicorn-backend-dc2