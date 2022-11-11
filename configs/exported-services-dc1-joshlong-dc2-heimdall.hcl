Kind = "exported-services"
Partition = "default"
Name = "default"
Services = [
  {
    Name = "joshs-obnoxiously-long-service-name-gonna-take-awhile"
    Namespace = "default"
    Consumers = [
      {
        PeerName = "DC2-heimdall"
      }
    ]
  }
]