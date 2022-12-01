Kind           = "service-resolver"
Name           = "unicorn-backend-failover"
Partition      = "unicorn"
Namespace      = "frontend"

ConnectTimeout = "0s"

Failover = {
  "*" = {
    Targets = [
      {
        Service = "unicorn-backend",
        Partition = "unicorn",
        Namespace = "backend"
      },
      {
        Service = "unicorn-backend",
        Peer = "dc2-unicorn",
        Namespace = "backend"
      }
    ]
  }
}

