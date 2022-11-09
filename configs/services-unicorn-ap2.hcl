services {
  id = "unicorn-frontend-0"
  name = "unicorn-frontend"
  address = "11.0.0.0"
  port = 6000
  partition = "unicorn"
  namespace = "frontend"
}
services {
  id = "unicorn-frontend-1"
  name = "unicorn-frontend"
  address = "11.0.0.1"
  port = 6000
  partition = "unicorn"
  namespace = "frontend"
}
services {
  id = "unicorn-frontend-2"
  name = "unicorn-frontend"
  address = "11.0.0.2"
  port = 6000
  partition = "unicorn"
  namespace = "frontend"
}

services {
  id = "unicorn-backend-0"
  name = "unicorn-backend"
  address = "11.0.0.0"
  port = 7000
  partition = "unicorn"
  namespace = "backend"
}
services {
  id = "unicorn-backend-1"
  name = "unicorn-backend"
  address = "11.0.0.1"
  port = 7000
  partition = "unicorn"
  namespace = "backend"
}
services {
  id = "unicorn-backend-2"
  name = "unicorn-backend"
  address = "11.0.0.2"
  port = 7000
  partition = "unicorn"
  namespace = "backend"
}
