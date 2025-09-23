output "role_arn" {
  description = "IAM role ARN for the Harness delegate (IRSA)"
  value       = aws_iam_role.delegate.arn
}