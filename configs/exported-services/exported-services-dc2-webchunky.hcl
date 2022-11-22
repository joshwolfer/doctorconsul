Kind = "exported-services"
Partition = "chunky"
Name = "chunky"
Services = [
  {
    Name = "web-chunky"
    Namespace = "default"
    Consumers = [
      {
        Peer = "DC1-default"
      }
    ]
  }
]