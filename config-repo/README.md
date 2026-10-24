# Central configuration

This directory is the native backend of `config-server`.

- `application.yml` contains shared management settings.
- `ticket-service.yml` contains Ticket Service port, context path and Eureka
  registration settings.

Changes are exposed by Config Server at
`http://localhost:8888/{application}/{profile}`.
