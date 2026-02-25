# aws/iam-irsa/variables.tf
variable "cluster_name" {
  description = "EKS cluster name (required when resolve_from_cluster = true)"
  type        = string
  default     = null
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
  description = "Existing OIDC provider ARN (set when creating EKS in same apply)."
  type        = string
  default     = null
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL (optional alternative to ARN when using existing cluster)."
  type        = string
  default     = null
}

variable "resolve_from_cluster" {
  description = "If true, read the cluster to discover OIDC (standalone mode). If false, rely on oidc_provider_arn / oidc_issuer_url passed in."
  type        = bool
  default     = true
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
    { "Effect": "Allow", "Action": ["sts:AssumeRole"], "Resource": "*" },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:DeleteLaunchTemplate",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:RunInstances",
        "ec2:CreateTags",
        "autoscaling:*",
        "elasticloadbalancing:*",
        "iam:PassRole",
        "iam:GetRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
