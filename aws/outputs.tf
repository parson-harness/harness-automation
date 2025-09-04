output "delegate_role_arn" {
  description = "IAM Role ARN for the Harness Delegate (IRSA)"
  value       = module.irsa_delegate.iam_role_arn
}

output "delegate_service_account_annotation" {
  description = "Annotate the delegate ServiceAccount with this"
  value       = "eks.amazonaws.com/role-arn: ${module.irsa_delegate.iam_role_arn}"
}
