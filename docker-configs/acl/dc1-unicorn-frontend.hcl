// service "whateverIwant" {
//   policy = "write"
// }

namespace_prefix "" {
  service_prefix "" {
      policy     = "read"
  }
  node_prefix "" {
      policy = "read"
  }
}

namespace "frontend" {
  service_prefix "unicorn-frontend"{
    policy  = "write"
  }
}