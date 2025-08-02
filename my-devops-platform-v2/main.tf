terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

# Configure the provider to talk to our running Minikube cluster.
# This explicitly points to the default kubeconfig location and context for Minikube.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# Define the namespace for our infrastructure applications.
resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

# Define the namespace for our deployed applications.
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}