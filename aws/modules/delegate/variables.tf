variable "delegate_namespace" {
  type = string
}

variable "delegate_service_account" {
  type = string
}

variable "delegate_name" {
  type = string
}

variable "delegate_release_name" {
  type = string
}

variable "delegate_account_id" {
  type = string
}

variable "delegate_token" {
  type      = string
  sensitive = true
}

variable "delegate_manager_endpoint" {
  type = string
}

variable "delegate_replicas" {
  type = number
}

variable "delegate_k8s_permissions_type" {
  type = string
}

variable "delegate_poll_for_tasks" {
  type = bool
}

variable "delegate_description" {
  type = string
}

variable "delegate_tags" {
  type = list(string)
}

variable "delegate_annotations" {
  type = map(string)
}

variable "delegate_custom_envs" {
  type = list(object({
    name  = string
    value = string
  }))
}

variable "delegate_chart_version" {
  type = string
}

variable "delegate_image_registry" {
  type = string
}

variable "delegate_image_repository" {
  type = string
}

variable "delegate_image_tag" {
  type = string
}

variable "delegate_upgrader_enabled" {
  type = bool
}

variable "delegate_upgrader_token" {
  type      = string
  sensitive = true
}

variable "irsa_role_arn" {
  type = string
}

variable "tag_owner" {
  type = string
}
