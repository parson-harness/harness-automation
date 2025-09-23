# Name of the cluster we are operating against (new or existing)
output "cluster_name" {
  description = "Target EKS cluster name"
  value       = var.create_eks ? module.eks[0].cluster_name : var.existing_cluster_name
}

# OIDC provider ARN (only available when we create the cluster here)
output "oidc_provider_arn" {
  description = "OIDC provider ARN (null if using existing cluster and not passed explicitly)"
  value       = var.create_eks ? module.eks[0].oidc_provider_arn : null
}

output "region" {
  description = "AWS region for the deployment"
  value       = var.region
}

# Delegate role from the decoupled iam-irsa stack
output "delegate_role_arn" {
  description = "IAM role ARN for the Harness delegate"
  value       = module.iam_irsa.role_arn
}
