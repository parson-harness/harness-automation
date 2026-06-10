# aws/eks/variables.tf
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

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "min_size" {
  description = "Minimum instance size for EKS managed node groups"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Max instance size for EKS managed node groups"
  type        = number
  default     = 2
}

variable "enable_cluster_autoscaler" {
  description = "If true, add Cluster Autoscaler discovery tags to managed node groups."
  type        = bool
  default     = false
}

variable "mixed_capacity_enabled" {
  description = "If true, create separate on-demand and spot managed node groups instead of the per-AZ layout"
  type        = bool
  default     = false
}

variable "spot_percentage" {
  description = "Percentage of total node group capacity to place on spot instances when mixed_capacity_enabled is true"
  type        = number
  default     = 0
}

variable "spot_instance_types" {
  description = "Optional instance types for the spot managed node group. If empty, instance_type is used"
  type        = list(string)
  default     = []
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

variable "warm_az" {
  description = "Availability Zone that keeps baseline EKS capacity warm. Leave null to keep all per-AZ node groups at zero desired nodes."
  type        = string
  default     = null
} # e.g. "us-east-1a"

variable "warm_desired" {
  description = "Desired baseline node count for the warm Availability Zone selected by warm_az."
  type        = number
  default     = 0
} # e.g. 1
