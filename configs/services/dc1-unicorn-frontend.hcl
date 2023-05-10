service {
  name = "unicorn-frontend"
  id = "unicorn-frontend-1"
  partition = "unicorn"
  namespace = "frontend"
  address = "10.5.0.110"
  port = 10000

  connect {
    sidecar_service {
      port = 20000

      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.5.0.110:20000"
        interval ="10s"
      }

      proxy {
        upstreams {
            destination_name = "unicorn-backend"  // This points to the service-resolver of the same name (SR: unicorn-backend)
            destination_namespace = "backend"
            local_bind_address = "127.0.0.1"
            local_bind_port = 11000
        }
        upstreams {
            destination_name = "unicorn-backend"
            destination_peer = "dc2-unicorn"
            destination_namespace = "backend"
            local_bind_address = "127.0.0.1"
            local_bind_port = 11001
        }
        upstreams {
            destination_name = "unicorn-backend"
            destination_peer = "dc3-default"
            destination_namespace = "unicorn"
            local_bind_address = "127.0.0.1"
            local_bind_port = 11002
        }
        upstreams {
            destination_name = "web-upstream"
            destination_partition = "default"
            destination_namespace = "default"
            local_bind_address = "127.0.0.1"
            local_bind_port = 11003
        }
      }
    }
  }
}