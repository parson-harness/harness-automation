# aws/variables.tf
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

variable "warm_az" {
  type    = string
  default = null
} # e.g. "us-east-1a"

variable "warm_desired" {
  type    = number
  default = 0
} # e.g. 1

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

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.32"
}

variable "min_size" {
  description = "Minimum size of cluster node group."
  type        = number
  default     = 0
}

variable "desired_size" {
  description = "Desired size of cluster node group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum size of cluster node group."
  type        = number
  default     = 3
}

variable "enable_cluster_autoscaler" {
  description = "Install Cluster Autoscaler for the EKS cluster."
  type        = bool
  default     = false
}

variable "cluster_autoscaler_namespace" {
  description = "Namespace where Cluster Autoscaler is installed."
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account_name" {
  description = "ServiceAccount name for Cluster Autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_version" {
  description = "Helm chart version for Cluster Autoscaler."
  type        = string
  default     = "9.37.0"
}

variable "cluster_autoscaler_image_tag" {
  description = "Cluster Autoscaler image tag. If empty, derive v<cluster_version>.0."
  type        = string
  default     = ""
}

variable "cluster_autoscaler_replica_count" {
  description = "Replica count for Cluster Autoscaler."
  type        = number
  default     = 1
}

variable "mixed_capacity_enabled" {
  description = "If true, create separate on-demand and spot managed node groups instead of the per-AZ layout."
  type        = bool
  default     = false
}

variable "spot_percentage" {
  description = "Percentage of total node group capacity to place on spot instances when mixed_capacity_enabled is true."
  type        = number
  default     = 0
  validation {
    condition     = var.spot_percentage >= 0 && var.spot_percentage <= 100
    error_message = "spot_percentage must be between 0 and 100."
  }
}

variable "spot_instance_types" {
  description = "Optional instance types for the spot managed node group. If empty, instance_type is used."
  type        = list(string)
  default     = []
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

variable "create_delegate" {
  description = "Install the Harness delegate via Terraform-managed Helm."
  type        = bool
  default     = false
}

variable "delegate_name" {
  description = "Harness delegate name."
  type        = string
  default     = ""
  validation {
    condition     = !var.create_delegate || length(trimspace(var.delegate_name)) > 0
    error_message = "delegate_name must be set when create_delegate is true."
  }
}

variable "delegate_release_name" {
  description = "Helm release name for the Harness delegate. Defaults to delegate_name when empty."
  type        = string
  default     = ""
}

variable "delegate_account_id" {
  description = "Harness account ID used by the delegate."
  type        = string
  default     = ""
  validation {
    condition     = !var.create_delegate || length(trimspace(var.delegate_account_id)) > 0
    error_message = "delegate_account_id must be set when create_delegate is true."
  }
}

variable "delegate_token" {
  description = "Harness delegate token."
  type        = string
  default     = ""
  sensitive   = true
  validation {
    condition     = !var.create_delegate || length(trimspace(var.delegate_token)) > 0
    error_message = "delegate_token must be set when create_delegate is true."
  }
}

variable "delegate_manager_endpoint" {
  description = "Harness manager endpoint for the delegate."
  type        = string
  default     = "https://app.harness.io"
}

variable "delegate_replicas" {
  description = "Number of Harness delegate replicas."
  type        = number
  default     = 1
}

variable "delegate_k8s_permissions_type" {
  description = "Harness delegate Kubernetes permissions mode, such as CLUSTER_ADMIN or CLUSTER_VIEWER."
  type        = string
  default     = "CLUSTER_ADMIN"
}

variable "delegate_poll_for_tasks" {
  description = "If true, the delegate polls for tasks instead of using socket connections."
  type        = bool
  default     = false
}

variable "delegate_description" {
  description = "Optional Harness delegate description."
  type        = string
  default     = ""
}

variable "delegate_tags" {
  description = "Optional list of Harness delegate tags."
  type        = list(string)
  default     = []
}

variable "delegate_annotations" {
  description = "Optional annotations to apply to the delegate pod and deployment."
  type        = map(string)
  default     = {}
}

variable "delegate_custom_envs" {
  description = "Optional additional environment variables for the delegate pod."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "delegate_chart_version" {
  description = "Optional Harness delegate Helm chart version. Leave empty to use the latest chart version from the repo."
  type        = string
  default     = ""
}

variable "delegate_image_registry" {
  description = "Container registry host for the Harness delegate image."
  type        = string
  default     = "us-docker.pkg.dev"
}

variable "delegate_image_repository" {
  description = "Repository path for the Harness delegate image inside the container registry."
  type        = string
  default     = "gar-prod-setup/harness-public/harness/delegate"
}

variable "delegate_image_tag" {
  description = "Optional delegate image tag override. Leave empty to resolve the latest plain release tag from public GAR."
  type        = string
  default     = ""
}

variable "delegate_upgrader_enabled" {
  description = "Enable the in-cluster Harness upgrader CronJob. Disabled by default because Terraform manages the delegate image version."
  type        = bool
  default     = false
}

variable "delegate_upgrader_token" {
  description = "Optional Harness upgrader token. If empty and upgrader is enabled, delegate_token is reused."
  type        = string
  default     = ""
  sensitive   = true
}

variable "allow_all_delegate_namespaces" {
  description = "If true, allow any ServiceAccount in harness-delegate-* namespaces to assume the IRSA role. Useful for multiple POV delegates."
  type        = bool
  default     = false
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
variable "replica_count" {
  description = "Number of Grafana replicas (0 = stop pods)"
  type        = number
  default     = 1
}

variable "grafana_service_type" {
  description = "Kubernetes Service type for Grafana (LoadBalancer or ClusterIP)"
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

variable "grafana_dashboards" {
  description = "List of community dashboards to auto-import."
  type = list(object({
    gnet_id    = number
    revision   = number
    datasource = string
  }))
  default = []
}

variable "grafana_host" {
  type = string
} # e.g., grafana.example.com
variable "grafana_use_alb" {
  type    = bool
  default = true
} # ALB path

variable "cluster_issuer_name" {
  type    = string
  default = "letsencrypt-prod"
}

# aws/variables.tf
variable "prometheus_url" {
  type        = string
  default     = ""
  description = "Optional Prometheus datasource URL for Grafana"
}
variable "prometheus_replicas" {
  type        = number
  description = "Prometheus replicas (0 pauses Prometheus pods)"
  default     = 1
}

variable "alertmanager_replicas" {
  type        = number
  description = "Alertmanager replicas (0 pauses Alertmanager pods)"
  default     = 1
}

variable "kube_state_metrics_enabled" {
  type        = bool
  description = "Enable kube-state-metrics deployment"
  default     = true
}

variable "node_exporter_enabled" {
  type        = bool
  description = "Enable node-exporter DaemonSet"
  default     = true
}

variable "create_sonarqube" {
  description = "Install SonarQube via Helm."
  type        = bool
  default     = false
}
variable "sonarqube_replica_count" {
  description = "Number of SonarQube replicas (0 pauses the SonarQube app while keeping the Helm release installed)."
  type        = number
  default     = 1
}
variable "sonarqube_monitoring_passcode" {
  type        = string
  description = "Passcode for SonarQube monitoring endpoint."
  sensitive   = true
  default     = "HarnessFTW!1"
}

variable "acme_email" {
  type        = string
  description = "Email used for Let's Encrypt notifications"
}
