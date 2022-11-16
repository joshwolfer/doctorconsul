Kind = "exported-services"
Partition = "default"
Name = "default"
Services = [
  {
    Name = "joshs-obnoxiously-long-service-name-gonna-take-awhile"
    Namespace = "default"
    Consumers = [
      {
        Peer = "DC2-default"
      }
    ]
  }
]