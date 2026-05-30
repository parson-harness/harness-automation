variable "cluster_name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "service_account_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "aws_region" {
  type = string
}

variable "chart_version" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "role_arn" {
  type = string
}
