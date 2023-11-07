Kind               = "sameness-group"
Name               = "web"
Partition          = "default"
DefaultForFailover = false
Members = [
  { Partition = "default" },
  { Peer = "dc2-chunky" }
]