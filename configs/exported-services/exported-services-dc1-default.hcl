Kind = "exported-services"
Partition = "default"
Name = "default"
Services = [
  {
    Name = "joshs-obnoxiously-long-service-name-gonna-take-awhile"
    Namespace = "default"
    Consumers = [
      {
        Peer = "dc2-default"
      }
    ]
  },
  {
    Name = "joshs-obnoxiously-long-service-name-gonna-take-awhile"
    Namespace = "default"
    Consumers = [
      {
        Peer = "dc2-heimdall"
      }
    ]
  }
]

