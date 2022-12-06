service {
  name = "web-upstream"
  id = "web-upstream-v1"
  address = "10.5.0.101"
  port = 8000

  connect {
    sidecar_service {
      port = 20000

      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.5.0.101:20000"
        interval ="10s"
      }
    }
  }
}
