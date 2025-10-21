# -------------------------------
# Cluster / Infra toggles
# -------------------------------
variable "create_eks" {
  description = "If true, create a new EKS cluster; if false, use existing_cluster_name."
  type        = bool
  default     = true
}

variable "existing_cluster_name" {
  description = "Existing EKS cluster name (required when create_eks=false)."
  type        = string
  default     = null
  validation {
    condition     = var.create_eks || (try(length(var.existing_cluster_name), 0) > 0)
    error_message = "When create_eks is false, you must set existing_cluster_name."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster" {
  description = "Base name for the EKS cluster (will be suffixed with tag_owner inside the EKS module)."
  type        = string
  default     = "harness-eks"
}

variable "tag_owner" {
  description = "Owner tag value (used for tagging and appended to cluster name)."
  type        = string
  default     = "HarnessPOV"
}

variable "instance_type" {
  description = "Instance type for EKS managed node groups."
  type        = string
  default     = "t3.large"
}

variable "delegate_namespace" {
  description = "K8s namespace for the Harness Delegate."
  type        = string
  default     = "harness-delegate-ng"
}

variable "delegate_service_account" {
  description = "K8s ServiceAccount used by the Harness Delegate."
  type        = string
  default     = "harness-delegate"
}

variable "artifacts_bucket" {
  description = "Optional S3 bucket name for artifacts (delegate gets R/W)."
  type        = string
  default     = ""
}

variable "ecr_repo_prefix" {
  description = "Optional ECR repo name prefix (e.g., 'pov-'); if empty, all repos allowed."
  type        = string
  default     = ""
}

variable "assume_role_arns" {
  description = "Optional list of IAM role ARNs in other accounts the delegate may assume."
  type        = list(string)
  default     = []
}

# -------------------------------
# StorageClass (cluster capability)
# -------------------------------
variable "create_default_storage_class" {
  description = "Create a default gp3 StorageClass provisioned by EBS CSI."
  type        = bool
  default     = true
}

variable "storage_class_name" {
  description = "Name of the default StorageClass to create."
  type        = string
  default     = "gp3"
}

variable "storage_class_volume_type" {
  description = "EBS volume 'type' parameter for the StorageClass."
  type        = string
  default     = "gp3"
}

# -------------------------------
# Grafana (optional app module)
# -------------------------------
variable "create_grafana" {
  description = "Install Grafana via Helm."
  type        = bool
  default     = false
}

variable "grafana_namespace" {
  description = "Namespace for Grafana."
  type        = string
  default     = "tools"
}

variable "grafana_release" {
  description = "Helm release name for Grafana."
  type        = string
  default     = "grafana"
}

variable "grafana_service_type" {
  description = "Kubernetes Service type for Grafana."
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_storage_size" {
  description = "PersistentVolume size for Grafana (passed to module as persistence_size)."
  type        = string
  default     = "5Gi"
}

variable "grafana_admin_user" {
  description = "Grafana admin username."
  type        = string
  default     = "admin"
}

variable "grafana_admin_pass" {
  description = "Grafana admin password (leave empty to let the chart generate one)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_prometheus_url" {
  description = "Optional internal URL for Prometheus datasource (e.g., http://kube-prometheus-stack-prometheus.monitoring.svc:9090)."
  type        = string
  default     = ""
}

variable "grafana_dashboards" {
  description = "List of community dashboards to auto-import."
  type = list(object({
    gnet_id    = number
    revision   = number
    datasource = string
  }))
  default = []
}
