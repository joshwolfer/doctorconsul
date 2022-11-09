node_name = "client-dc1-alpha"
datacenter = "dc1"
partition = "default"

data_dir = "/consul/data"
log_level = "INFO"
retry_join = ["consul-server1-dc1"]

encrypt = "aPuGh+5UDskRAbkLaXRzFoSOcSM+5vAK+NEYOWHJH7w="

acl {
  enabled = true
  tokens {
    agent = "00000000-0000-0000-0000-000000001111"
    default = "00000000-0000-0000-0000-000000001111"
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