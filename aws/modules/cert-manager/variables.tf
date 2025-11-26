variable "namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace for cert-manager"
}

variable "chart_version" {
  type    = string
  default = "v1.15.3" # pin a recent, stable version
}

variable "acme_email" {
  type        = string
  description = "Email for Let's Encrypt ACME registrations"
}

variable "ingress_class" {
  type        = string
  default     = "nginx"
  description = "Ingress class used by HTTP-01 solver"
}
