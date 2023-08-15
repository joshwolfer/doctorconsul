Kind = "service-intentions"
Name = "unicorn-backend"
partition = "unicorn"
namespace = "backend"
Sources = [
  {
    Name      = "unicorn-frontend"
    namespace = "frontend"
    peer      = "dc1-unicorn"
    Action    = "allow"
  },
]

