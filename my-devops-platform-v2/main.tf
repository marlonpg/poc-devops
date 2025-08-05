# main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
  }
}

# Configure the Kubernetes provider to talk to our running Minikube cluster.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# Configure the Helm provider to use the same Kubernetes context.
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

# --- Base Namespaces ---
resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

# --- Helm Releases (Application Installations) ---

# Install Prometheus using the helm_release resource.
# The repository URL is now specified directly in this resource.
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  # Ensure the namespace exists before trying to install.
  depends_on = [kubernetes_namespace.infra]
}

# Install Jenkins using the helm_release resource.
# The repository URL is now specified directly in this resource.
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  # Load the configuration from our values file.
  values = [
    file("${path.module}/helm/values/jenkins-values.yaml")
  ]

  # Ensure the namespace exists first.
  depends_on = [kubernetes_namespace.infra]
}