# aws/eks/outputs.tf
output "delegate_role_arn" {
  description = "IAM Role ARN for the Harness Delegate (IRSA)"
  value       = module.irsa_delegate.iam_role_arn
}

output "delegate_service_account_annotation" {
  description = "Annotate the delegate ServiceAccount with this"
  value       = "eks.amazonaws.com/role-arn: ${module.irsa_delegate.iam_role_arn}"
}

# Surface the cluster name from the upstream EKS module
output "cluster_name" {
  description = "Name of the created EKS cluster"
  value       = module.eks.cluster_name
}

# Handy for other stacks or scripts
output "region" {
  description = "AWS region resolved from the provider"
  value       = data.aws_region.current.name
}

# Useful if any caller needs the OIDC issuer URL (IRSA)
output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

# If your delegate bits ever need these, you can expose them too:
# output "delegate_namespace" {
#   value = var.delegate_namespace
# }
# output "delegate_service_account" {
#   value = var.delegate_service_account
# }
