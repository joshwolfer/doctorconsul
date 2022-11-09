partition "default" {
  operator = "read"
}

partition "proj1" {
  namespace_prefix "" {
    service_prefix "" {
        policy     = "write"
        intentions = "write"
    }
    node_prefix "" {
        policy = "read"
    }
  }
}


