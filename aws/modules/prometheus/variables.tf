# aws/modules/prometheus/variables.tf
variable "namespace" {
  type        = string
  description = "Namespace where kube-prometheus-stack is installed"
  default     = "tools"
}

variable "release_name" {
  type        = string
  description = "Helm release name for kube-prometheus-stack"
  default     = "monitoring"
}

# Optional pin so you get reproducible installs
variable "chart_version" {
  type        = string
  description = "kube-prometheus-stack chart version (optional)"
  default     = "65.5.0"
}

variable "prometheus_replicas" {
  description = "Prometheus replicas (0 pauses Prometheus pods)"
  type        = number
  default     = 1
}

variable "alertmanager_replicas" {
  description = "Alertmanager replicas (0 pauses Alertmanager pods)"
  type        = number
  default     = 1
}

variable "kube_state_metrics_enabled" {
  description = "Enable kube-state-metrics deployment"
  type        = bool
  default     = true
}

variable "node_exporter_enabled" {
  description = "Enable node-exporter DaemonSet"
  type        = bool
  default     = true
}