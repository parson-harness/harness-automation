variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster" {
  description = "EKS cluster name"
  type        = string
  default     = "parson-eks"
}

variable "instance_type" {
  description = "Instance type for EKS managed node groups"
  type        = string
  default     = "t3.large"
}

variable "tag_owner" {
  description = "Owner tag value"
  type        = string
  default     = "parson"
}

variable "delegate_namespace" {
  description = "K8s namespace for the Harness Delegate"
  type        = string
  default     = "harness-delegate-ng"
}

variable "delegate_service_account" {
  description = "K8s ServiceAccount used by the Harness Delegate"
  type        = string
  default     = "harness-delegate"
}

variable "artifacts_bucket" {
  description = "Optional S3 bucket name; if set, delegate gets R/W on this bucket"
  type        = string
  default     = ""
}

variable "ecr_repo_prefix" {
  description = "Optional ECR repo name prefix (e.g., 'pov-'); if empty, all repos allowed"
  type        = string
  default     = ""
}

variable "assume_role_arns" {
  description = "Optional list of IAM role ARNs in other accounts the delegate may assume"
  type        = list(string)
  default     = []
}
