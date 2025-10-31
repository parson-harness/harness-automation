variable "enabled" {
  description = "Whether to install SonarQube. Set to false to skip or de-provision."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Kubernetes namespace for SonarQube."
  type        = string
  default     = "tools"
}

variable "create_namespace" {
  description = "Create the namespace if it does not exist."
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "sonarqube"
}

variable "chart_name" {
  description = "Helm chart name."
  type        = string
  default     = "sonarqube"
}

variable "chart_repo" {
  description = "Helm repository URL for the SonarQube chart."
  type        = string
  default     = "https://SonarSource.github.io/helm-chart-sonarqube"
}

variable "chart_version" {
  description = "Chart version (recommend pinning). Leave null to let Helm pick latest."
  type        = string
  default     = null
}

variable "service_type" {
  description = "K8s Service type for SonarQube."
  type        = string
  default     = "LoadBalancer"
}

variable "storage_class_name" {
  description = "StorageClass for SonarQube PVCs (e.g., gp3, gp2, gp3-csi)."
  type        = string
  default     = "gp3"
}

variable "persistence_size" {
  description = "Requested PVC size."
  type        = string
  default     = "20Gi"
}

variable "resources" {
  description = "CPU/memory resources for the SonarQube pod."
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2"
      memory = "4Gi"
    }
  }
}

variable "extra_values" {
  description = "Additional Helm values as a raw YAML string to merge."
  type        = string
  default     = ""
}

variable "annotations" {
  description = "Annotations to add to the Service (e.g., AWS LB annotations)."
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Optional nodeSelector for SonarQube pods."
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Optional tolerations for SonarQube pods."
  type        = list(any)
  default     = []
}
