# aws/eks/outputs.tf

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

# Useful for wiring IRSA in a separate module
output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}
