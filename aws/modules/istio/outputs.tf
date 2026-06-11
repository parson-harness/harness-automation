locals {
  gateway_service_name = can(one(data.kubernetes_service_v1.ingress_gateway[*].metadata[0].name)) ? one(data.kubernetes_service_v1.ingress_gateway[*].metadata[0].name) : null
}

output "namespace" {
  description = "Namespace where Istio control plane components are installed."
  value       = var.enabled ? var.namespace : null
}

output "gateway_namespace" {
  description = "Namespace where the shared Istio ingress gateway is installed."
  value       = var.enabled ? var.gateway_namespace : null
}

output "gateway_service_name" {
  description = "Kubernetes Service name for the shared Istio ingress gateway."
  value       = local.gateway_service_name
}

output "gateway_load_balancer_hostname" {
  description = "Load balancer hostname for the shared Istio ingress gateway, if available."
  value       = try(data.kubernetes_service_v1.ingress_gateway[0].status[0].load_balancer[0].ingress[0].hostname, null)
}

output "gateway_load_balancer_ip" {
  description = "Load balancer IP for the shared Istio ingress gateway, if available."
  value       = try(data.kubernetes_service_v1.ingress_gateway[0].status[0].load_balancer[0].ingress[0].ip, null)
}

output "kiali_namespace" {
  description = "Namespace where Kiali is installed when enabled."
  value       = var.enabled && var.enable_kiali ? var.kiali_namespace : null
}
