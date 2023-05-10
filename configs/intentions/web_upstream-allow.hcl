Kind = "service-intentions"
Name = "web-upstream"
Sources = [
  {
    Name   = "web"
    Action = "allow"
  },
  {
    Name      = "unicorn-frontend"
    namespace = "frontend"
    partition = "unicorn"
    Action = "allow"
  }
]