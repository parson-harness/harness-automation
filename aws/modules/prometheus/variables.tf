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