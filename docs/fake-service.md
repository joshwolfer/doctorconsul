# Fake Service Application Details

* Environment variables for the FakeService:
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