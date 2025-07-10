# poc-devops

# Build a deployment system with:
- Jenkins
- Helm
- OpenTofu
- Minikub or other kubernetes cluster manager
- Prometheus
- Grafana

* Requirements: You need to be able to deploy an application with all this tools and you need 2 clusters (or 2 namespaces) one for the infra and other for the apps that will be deployed. The pipelines in Jenkins need to run tests and fail if tests fail. OpenTofu need to have automated tests as well, all apps deployed need to be integrated with Grafana and Prometheus by default.