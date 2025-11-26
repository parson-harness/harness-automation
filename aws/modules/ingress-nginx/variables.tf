# aws/ingress-nginx/variables.tf
variable "namespace" {
  type        = string
  default     = "ingress-nginx"
  description = "Namespace to install the ingress controller"
}

variable "release_name" {
  type        = string
  default     = "ingress-nginx"
  description = "Helm release name"
}

variable "chart_version" {
  type        = string
  default     = "4.11.1"
  description = "Ingress nginx chart version"
}

# AWS LB knobs
variable "lb_type" {
  type    = string
  default = "nlb" # nlb | classic (for CLB) — ALB requires AWS LB Controller, different chart
}

variable "lb_scheme" {
  type    = string
  default = "internet-facing" # or "internal"
}

# Optional additional Helm values (merged last)
variable "extra_values" {
  type        = map(any)
  default     = {}
  description = "Arbitrary values merged into the chart (yamlencoded)."
}
