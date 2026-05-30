terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
