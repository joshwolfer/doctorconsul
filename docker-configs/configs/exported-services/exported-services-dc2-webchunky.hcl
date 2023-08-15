Kind = "exported-services"
Partition = "chunky"
Name = "chunky"
Services = [
  {
    Name = "web-chunky"
    Namespace = "default"
    Consumers = [
      {
        Peer = "dc1-default"
      }
    ]
  }
]

