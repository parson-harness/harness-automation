# aws/outputs.tf
# Name of the cluster we are operating against (new or existing)
output "cluster_name" {
  description = "Target EKS cluster name"
  value       = local.target_cluster_name
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (null if using existing cluster and not created here)"
  value       = var.create_eks ? module.eks[0].oidc_provider_arn : null
}

output "region" {
  description = "AWS region for the deployment"
  value       = var.region
}

output "delegate_role_arn" {
  description = "IAM role ARN for the Harness delegate"
  value       = module.iam_irsa.role_arn
}

# Nice-to-have Grafana hints (null when not created)
output "grafana_namespace" {
  value       = var.create_grafana ? module.grafana[0].namespace : null
  description = "Grafana namespace (if installed)"
}

output "grafana_admin_password_cmd" {
  value       = var.create_grafana ? module.grafana[0].admin_password_cmd : null
  description = "Command to print Grafana admin password (if auto-generated)"
}

output "grafana_url" {
  value       = var.create_grafana ? module.grafana[0].url : null
  description = "Grafana URL"
}

output "grafana_svc_hint" {
  value       = var.create_grafana ? module.grafana[0].svc_hint : null
  description = "Command to get the Grafana Service (EXTERNAL-IP)"
}

output "suggested_grafana_host" {
  value = local.grafana_host_effective
}

output "grafana_effective_host" {
  description = "Final hostname used for Grafana (explicit or sslip.io), if any."
  value       = try(local.grafana_host_effective, null)
}

output "grafana_effective_url" {
  description = "Final HTTPS URL to Grafana if a host was resolved."
  value       = local.grafana_host_effective != null ? format("https://%s", local.grafana_host_effective) : null
}

output "prometheus_namespace" {
  description = "Namespace where Prometheus stack is deployed."
  value       = try(module.prometheus.namespace, null)
}

output "prometheus_release_name" {
  description = "Helm release name for the Prometheus stack."
  value       = try(module.prometheus.release_name, null)
}

output "prometheus_svc_hint" {
  description = "Command to list Prometheus services."
  value       = "kubectl get svc -n ${var.grafana_namespace} -l app.kubernetes.io/name=prometheus -o wide"
}

output "prometheus_url" {
  description = "Internal or external URL for Prometheus (if exposed)."
  value       = try(module.prometheus.prometheus_url, null)
}

output "prometheus_alertmanager_url" {
  description = "Internal or external URL for Alertmanager (if exposed)."
  value       = try(module.prometheus.alertmanager_url, null)
}

output "prometheus_lb_hostname" {
  description = "LoadBalancer hostname for Prometheus."
  value       = try(module.prometheus.load_balancer_hostname, null)
}

output "prometheus_lb_ip" {
  description = "LoadBalancer IP for Prometheus."
  value       = try(module.prometheus.load_balancer_ip, null)
}

output "sonarqube_namespace" {
  description = "Namespace where SonarQube is deployed."
  value       = try(module.sonarqube.namespace, null)
}

output "sonarqube_lb_hostname" {
  description = "External LB hostname for SonarQube (if available)."
  value       = try(module.sonarqube.load_balancer_hostname, null)
}

output "sonarqube_lb_ip" {
  description = "External LB IP for SonarQube (if available)."
  value       = try(module.sonarqube.load_balancer_ip, null)
}

output "sonarqube_svc_hint" {
  description = "Command to list the SonarQube service."
  value       = "kubectl get svc -n ${var.grafana_namespace} -l app.kubernetes.io/name=sonarqube -o wide"
}
