service {
  name = "unicorn-backend"
  id = "unicorn-backend-1"
  partition = "unicorn"
  namespace = "backend"
  address = "10.6.0.111"
  port = 10001

  connect {
    sidecar_service {
      port = 20000

      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.6.0.111:20000"
        interval ="10s"
      }
    }
  }
}