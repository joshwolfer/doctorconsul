Kind = "exported-services"
Partition = "donkey"
Name = "donkey"
Services = [
  {
    Name = "donkey"
    Namespace = "default"
    Consumers = [
      {
        Partition = "default"
      }
    ]
  }
]