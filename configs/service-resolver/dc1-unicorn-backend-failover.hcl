Kind           = "service-resolver"
Name           = "unicorn-backend"
Partition      = "unicorn"
Namespace      = "backend"

ConnectTimeout = "0s"

Failover = {
  "*" = {
    Targets = [
      {
        Service = "unicorn-backend",
        Peer = "dc2-unicorn",
        Namespace = "backend"
      }
    ]
  }
}

