Kind = "exported-services"
Partition = "default"
Name = "default"
Services = [
  {
    Name = "josh"
    Namespace = "default"
    Consumers = [
      {
        Peer = "dc1-default"
      }
    ]
  }
]