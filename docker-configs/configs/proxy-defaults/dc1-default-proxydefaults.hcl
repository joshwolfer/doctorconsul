Kind = "proxy-defaults"
Name = "global"
Partition = "default"

Config {
  envoy_prometheus_bind_addr = "0.0.0.0:9102"
  protocol = "http"
}