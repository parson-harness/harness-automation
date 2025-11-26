# aws/providers.tf
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.24.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.10.1, < 4.0.0" }
    external   = { source = "hashicorp/external", version = ">= 2.3.0, < 3.0.0" }
    dns        = { source = "hashicorp/dns" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.19.0" }
  }
}

provider "aws" {
  region = var.region
}
provider "kubernetes" {
  config_path = "~/.kube/config"
  # (optional) lock to this cluster context
  # config_context_cluster = "arn:aws:eks:us-east-1:759984737373:cluster/harness-eks-parson"
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}


# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#     # config_context_cluster = "arn:aws:eks:us-east-1:759984737373:cluster/harness-eks-parson"
#   }
# }

# You can keep kubectl if something needs it; otherwise it’s optional
provider "kubectl" {
  load_config_file = true
  config_path      = "~/.kube/config"
}
