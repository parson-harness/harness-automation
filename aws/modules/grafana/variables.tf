variable "namespace" {
  type        = string
  default     = "tools"
  description = "Kubernetes namespace for Grafana"
}

variable "release_name" {
  type        = string
  default     = "grafana"
  description = "Helm release name"
}

variable "service_type" {
  type        = string
  default     = "LoadBalancer"
  description = "Service type for Grafana"
}

variable "persistence_enabled" {
  type        = bool
  default     = true
  description = "Enable persistent storage for Grafana"
}

variable "persistence_size" {
  type        = string
  default     = "5Gi"
  description = "Size of Grafana persistent volume"
}

variable "persistence_sc_name" {
  type        = string
  default     = ""
  description = "Optional StorageClass name (leave blank to use default)"
}

variable "admin_user" {
  type        = string
  default     = "admin"
  description = "Grafana admin username"
}

variable "admin_password" {
  type        = string
  default     = ""
  description = "Grafana admin password (leave blank for random)"
}

variable "prometheus_url" {
  type        = string
  default     = ""
  description = "Optional Prometheus datasource URL"
}

variable "dashboards" {
  description = "List of dashboards to import"
  type = list(object({
    gnet_id    = number
    revision   = number
    datasource = string
  }))
  default = []
}

variable "timeout_seconds" {
  type        = number
  default     = 1200
  description = "Timeout for Helm release (seconds)"
}
