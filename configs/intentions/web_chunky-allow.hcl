Kind = "service-intentions"
Name = "web-chunky"
partition = "chunky"
Sources = [
  {
    Name   = "web"
    peer   = "dc1-default"
    Action = "allow"
  }
]

