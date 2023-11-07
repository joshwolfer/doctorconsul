Kind               = "sameness-group"
Name               = "unicorn"
Partition          = "unicorn"
DefaultForFailover = false
Members = [
  { Partition = "unicorn" },
  { Peer = "dc2-unicorn" },
  { Peer = "dc3-default" },
  { Peer = "dc3-cernunnos" },
  { Peer = "dc4-default" },
  { Peer = "dc4-taranis" }
]