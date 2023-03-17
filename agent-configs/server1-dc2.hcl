node_name = "consul-server1-dc2"
datacenter = "dc2"
server = true
license_path = "/consul/config/license"

log_level = "INFO"

peering { enabled = true }

ui_config = {
  enabled = true

  metrics_provider = "prometheus"
  metrics_proxy = {
    base_url = "http://10.6.0.200:9090"
  }
}

data_dir = "/consul/data"

addresses = {
  http = "0.0.0.0"
  grpc = "0.0.0.0"
  grpc_tls = "0.0.0.0"
}

ports = {
  grpc = 8502
  grpc_tls = 8503
}

acl {
  enabled = true
  default_policy = "deny"
  down_policy = "extend-cache"
  enable_token_persistence = true

  tokens {
    initial_management = "root"
    agent = "root"
    default = ""
  }
}

auto_encrypt = {
  allow_tls = true
}

encrypt = "dznVKWl1ri975FUJiddzAPM+3eNP9iXDad2c8hghsKA="

tls {
  defaults {
    ca_file = "/consul/config/certs/consul-agent-ca.pem"
    cert_file = "/consul/config/certs/dc2-server-consul-0.pem"
    key_file = "/consul/config/certs/dc2-server-consul-0-key.pem"

    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

auto_reload_config = true