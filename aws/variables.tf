# aws/variables.tf
variable "region" {
  description = "AWS region for all stacks"
  type        = string
  default     = "us-east-1"
}

variable "cluster" {
  description = "Base name for the EKS cluster (will be suffixed with tag_owner)"
  type        = string
  default     = "harness-eks"
}

variable "tag_owner" {
  description = "Owner tag value (used for tagging and appended to cluster name)"
  type        = string
  default     = "HarnessPOV"
}

variable "instance_type" {
  description = "Instance type for EKS managed node groups"
  type        = string
  default     = "t3.large"
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

# Root toggles to support both paths:
variable "create_eks" {
  description = "If true, create a new EKS cluster. If false, use an existing cluster."
  type        = bool
  default     = true
}

variable "existing_cluster_name" {
  description = "Name of an existing EKS cluster (used when create_eks=false)"
  type        = string
  default     = null
  validation {
    condition     = var.create_eks || (try(length(var.existing_cluster_name), 0) > 0)
    error_message = "When create_eks is false, you must set existing_cluster_name."
  }
}
