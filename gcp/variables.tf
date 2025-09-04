variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region where resources will be created"
  type        = string
}

variable "label" {
  description = "A unique identifier for the cloud resources provisioned by this TF"
  type        = string
  default     = "harness"  # Optional: provide a default value
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

variable "machine_type" {
  default     = "n1-standard-1"
  description = "The type of machines used in the node pool"
}
