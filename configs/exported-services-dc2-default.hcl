Kind = "exported-services"
Partition = "default"
Name = "default"
Services = [
  {
    Name = "josh"
    Namespace = "default"
    Consumers = [
      {
        PeerName = "DC1"
      }
    ]
  }
]