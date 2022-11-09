node_name = "client-dc2-bravo"
datacenter = "dc2"
partition = "default"

data_dir = "/consul/data"
log_level = "INFO"
retry_join = ["consul-server1-dc2"]

encrypt = "dznVKWl1ri975FUJiddzAPM+3eNP9iXDad2c8hghsKA="

acl {
  enabled = true
  tokens {
    agent = "root"
    default = "root"
  }
}

auto_encrypt = {
  tls = true
}

tls {
  defaults {
    ca_file = "/consul/config/certs/consul-agent-ca.pem"

    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

auto_reload_config = true