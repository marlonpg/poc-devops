provider "kubernetes" {
  host                   = "https://192.168.49.2:8443"
  cluster_ca_certificate = file(pathexpand("~/.minikube/ca.crt"))
  client_certificate     = file(pathexpand("~/.minikube/profiles/minikube/client.crt"))
  client_key             = file(pathexpand("~/.minikube/profiles/minikube/client.key"))
}

provider "helm" {
  kubernetes {
    host                   = "https://192.168.49.2:8443"
    cluster_ca_certificate = file(pathexpand("~/.minikube/ca.crt"))
    client_certificate     = file(pathexpand("~/.minikube/profiles/minikube/client.crt"))
    client_key             = file(pathexpand("~/.minikube/profiles/minikube/client.key"))
  }
}