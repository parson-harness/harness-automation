# aws/iam-irsa/variables.tf
variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the delegate ServiceAccount lives"
  type        = string
  default     = "harness-delegate-ng"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name used by the delegate"
  type        = string
  default     = "harness-delegate"
}

variable "role_name" {
  description = "Name for the IAM role to be assumed via IRSA"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "Existing OIDC provider ARN (optional). If not set, it will be looked up from the cluster."
  type        = string
  default     = null
}

variable "inline_policy_json" {
  description = "JSON for the delegate IAM policy. Provide least-privilege required for your use case."
  type        = string
  default     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["ecr:GetAuthorizationToken","ecr:BatchCheckLayerAvailability","ecr:GetDownloadUrlForLayer","ecr:BatchGetImage"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["sts:AssumeRole"], "Resource": "*" }
  ]
}
EOF
}
