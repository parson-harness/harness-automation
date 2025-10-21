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

output "grafana_svc_hint" {
  value       = var.create_grafana ? module.grafana[0].svc_hint : null
  description = "Command to get the Grafana Service (EXTERNAL-IP)"
}