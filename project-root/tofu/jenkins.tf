resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = "infra"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.1.7" # You can update to latest version if you want

  values = [
    file("${path.module}/jenkins-values.yaml")
  ]
}