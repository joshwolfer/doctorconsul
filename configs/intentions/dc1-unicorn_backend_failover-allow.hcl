Kind = "service-intentions"
Name = "unicorn-backend-failover"
partition = "unicorn"
namespace = "frontend"
Sources = [
  {
    Name      = "unicorn-frontend"
    partition = "unicorn"
    namespace = "frontend"
    Action    = "allow"
  }
]
