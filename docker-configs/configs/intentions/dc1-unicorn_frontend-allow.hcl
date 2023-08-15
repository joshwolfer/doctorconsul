Kind = "service-intentions"
Name = "unicorn-backend"
partition = "unicorn"
namespace = "backend"
Sources = [
  {
    Name      = "unicorn-frontend"
    partition = "unicorn"
    namespace = "frontend"
    Action    = "allow"
  }
]
