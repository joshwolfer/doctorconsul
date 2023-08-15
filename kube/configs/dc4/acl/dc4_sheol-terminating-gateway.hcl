namespace "sheol" {
  service "sheol-ext" {
    policy = "write"
  }
}

namespace "sheol-app1" {
  service "sheol-ext1" {
    policy = "write"
  }
}

namespace "sheol-app2" {
  service "sheol-ext2" {
    policy = "write"
  }
}