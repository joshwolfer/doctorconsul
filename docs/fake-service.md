# Doctor Consul Applications

There are 4 core "applications" deployed into the Doctor Consul environment, each with an accessible  application UI:

* Web Service UI: http://127.0.0.1:9000/ui
* Unicorn-frontend (unicorn) DC1 UI: http://127.0.0.1:10000/ui
* Unicorn-frontend (unicorn) DC3 UI: http://127.0.0.1:11000/ui
* Unicorn-ssg-frontend (unicorn) DC3 UI: http://127.0.0.1:11001/ui

# Fake Service Application Details

Nic Jackson's Fake Service is a powerful light-weight application used to demonstrate various mesh functionality within Doctor Consul. It can be found here:

* Github: [HERE](https://github.com/nicholasjackson/fake-service)
* Dockerhub: [HERE](https://hub.docker.com/r/nicholasjackson/fake-service/tags)

Each application has a single downstream service with a Web UI, that connects to one or more upstreams services, using various mesh routing options. Within the UI of each application, is a heirarchical view of the downastream and upstream services. Clicking on the "click here for description" link within each service block will provide more details about what is happening within the application. 

### Fake Service Variables

The Fake Service behaviors are configured complete through environment variables within the `docker-compose.yml` file. 

* Complete list of environment variables for the FakeService:

  * [https://hub.docker.com/r/nicholasjackson/fake-service](https://hub.docker.com/r/nicholasjackson/fake-servicehttps:/)

### Most useful FakeService Variables

#### Service Listener


| **Variable**              | **Meaning**                                                                             |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| LISTEN_ADDR: 0.0.0.0:9090 | IP address and port to bind service to                                                  |
| MESSAGE: "Hello World"    | Message to be returned from service, can either be a string or valid JSON               |
| SERVER_TYPE: "http"       | Service type: [http or grpc], default:http. Determines the type of service HTTP or gRPC |
| NAME: "Service_name"      | Name of the service                                                                     |

### Fault Injection


| **Variable**             | **Meaning**                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------ |
| ERROR_RATE: "0"          | Decimal percentage of request where handler will report an error. (0.1 = 10% will error) |
| ERROR_TYPE: "http_error" | Type of error [http_error, delay]                                                        |
| ERROR_CODE: "500"        | Error code to return on error                                                            |

#### Upstream Settings


| **Variable**                         | **Meaning**                                           |
| -------------------------------------- | ------------------------------------------------------- |
| UPSTREAM_URIS: http://localhost:9091 | Comma separated URIs of the upstream services to call |
| HTTP_CLIENT_KEEP_ALIVES: "false"     | Enable HTTP connection keep alives for upstream calls |
| HTTP_CLIENT_REQUEST_TIMEOUT: "30s"   | Maximum duration for upstream service requests        |
