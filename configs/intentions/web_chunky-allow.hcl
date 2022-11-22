Kind = "service-intentions"
Name = "web-chunky"
partition = "chunky"
Sources = [
  {
    Name   = "web"
    peer   = "DC1-default"
    Action = "allow"
  }
]