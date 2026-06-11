variable "enabled" {
  description = "Whether to install the shared Istio control plane components."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace for Istio control plane components."
  type        = string
  default     = "istio-system"
}

variable "gateway_namespace" {
  description = "Namespace for the shared Istio ingress gateway."
  type        = string
  default     = "istio-ingress"
}

variable "chart_version" {
  description = "Istio Helm chart version used for base, istiod, and gateway."
  type        = string
  default     = "1.24.3"
}

variable "istiod_replica_count" {
  description = "Replica count for istiod."
  type        = number
  default     = 1
}

variable "ingress_gateway_replica_count" {
  description = "Replica count for the shared Istio ingress gateway."
  type        = number
  default     = 1
}

variable "ingress_gateway_service_type" {
  description = "Kubernetes Service type for the shared Istio ingress gateway."
  type        = string
  default     = "LoadBalancer"
}

variable "ingress_gateway_service_annotations" {
  description = "Optional annotations for the shared Istio ingress gateway Service."
  type        = map(string)
  default     = {}
}

variable "enable_kiali" {
  description = "Whether to install Kiali for basic mesh visibility."
  type        = bool
  default     = false
}

variable "kiali_namespace" {
  description = "Namespace for Kiali when enabled."
  type        = string
  default     = "kiali"
}

variable "kiali_chart_version" {
  description = "Optional Kiali chart version. Leave null to let Helm pick the latest chart from the repo."
  type        = string
  default     = null
}

variable "kiali_service_type" {
  description = "Kubernetes Service type for Kiali."
  type        = string
  default     = "ClusterIP"
}

variable "prometheus_url" {
  description = "Prometheus URL used by Kiali when enabled."
  type        = string
  default     = ""
}
