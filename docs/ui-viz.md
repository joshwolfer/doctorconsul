# UI Visualization metrics using Prometheus

Consul UI metrics are enabled in all of the Consul clusters. This provides extra details about each service mesh service, directly within the Consul UI.

Consul Docs: [HERE](https://developer.hashicorp.com/consul/docs/connect/observability/ui-visualizationhttps:/)

Docter Consul has two different prometheus servers:

* `prometheus` in docker-compose, used for DC1 and DC2.
* `prometheus-server` in K3d, used for k3d DC3.

## Overview

There are three key components to making the Consul UI visualizations work:

1. Each application Envoy side-car proxy exposes metrics via a Prometheus listener.
2. Prometheus servers are configured to connect to each Envoy listener and "scrape" these metrics every 30s.
3. The Consul UI connects to the configured Prometheus server to fetch

### Other Details

The UI visualizations can take between 30-60s to show any data, from the time you refresh the fake service application. Be patient. :)
