Kind = "proxy-defaults"
Name = "global"
Partition = "unicorn"

Config {
  envoy_prometheus_bind_addr = "0.0.0.0:9102"
  protocol = "http"
}