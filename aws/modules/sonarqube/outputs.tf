output "namespace" {
  description = "Namespace where SonarQube is deployed."
  value       = var.enabled ? var.namespace : null
}

output "release_name" {
  description = "Helm release name."
  value       = var.enabled ? var.release_name : null
}

# If Service is LoadBalancer, expose its hostname/IP when available.
data "kubernetes_service" "lb" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-sonarqube"
    namespace = var.namespace
  }

  # Not all charts name the service identically; this is the common default.
  # If your chart names differ, override via extra_values or adjust this.
}

output "load_balancer_hostname" {
  description = "External hostname for SonarQube (if Service type is LoadBalancer)."
  value       = var.enabled ? try(data.kubernetes_service.lb[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
}

output "load_balancer_ip" {
  description = "External IP for SonarQube (if Service type is LoadBalancer)."
  value       = var.enabled ? try(data.kubernetes_service.lb[0].status[0].load_balancer[0].ingress[0].ip, null) : null
}
