service {
  name = "web-chunky"
  id = "web-chunky-v1"
  partition = "chunky"
  address = "10.6.0.100"
  port = 8000

  connect {
    sidecar_service {
      port = 20000

      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.6.0.100:20000"
        interval ="10s"
      }
    }
  }
}
