# aws/main.tf

# Optionally create EKS
module "eks" {
  source = "./modules/eks"
  count  = var.create_eks ? 1 : 0

  cluster                  = var.cluster
  tag_owner                = var.tag_owner
  instance_type            = var.instance_type
  delegate_namespace       = var.delegate_namespace
  delegate_service_account = var.delegate_service_account
  artifacts_bucket         = var.artifacts_bucket
  ecr_repo_prefix          = var.ecr_repo_prefix
  assume_role_arns         = var.assume_role_arns
}

# Resolve target cluster name for both paths
locals {
  target_cluster_name = var.create_eks ? module.eks[0].cluster_name : var.existing_cluster_name
  # If a root-level override is provided (e.g., in terraform.tfvars), use it.
  # Otherwise fall back to the Prometheus module’s output.
  prometheus_url_effective = (
    var.prometheus_url != "" ? var.prometheus_url : module.prometheus.prometheus_url
  )
}

# IRSA for the delegate
module "iam_irsa" {
  source               = "./modules/iam-irsa"
  cluster_name         = local.target_cluster_name
  namespace            = var.delegate_namespace
  service_account_name = var.delegate_service_account

  resolve_from_cluster = var.create_eks ? false : true
  oidc_provider_arn    = var.create_eks ? module.eks[0].oidc_provider_arn : null
  oidc_issuer_url      = var.create_eks ? module.eks[0].cluster_oidc_issuer_url : null
}

# Providers use these data sources (works for both new/existing clusters)
data "aws_eks_cluster" "this" {
  name = local.target_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.target_cluster_name
}

# Create a default gp3 CSI StorageClass (cluster capability)
resource "kubernetes_storage_class" "default_gp3" {
  count = var.create_default_storage_class ? 1 : 0

  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    type = var.storage_class_volume_type
  }

  # Safe dependency that works whether module.eks ran or not
  depends_on = [data.aws_eks_cluster.this]
}

module "prometheus" {
  source    = "./modules/prometheus"
  namespace = "tools"
  # release_name = "monitoring" # optional override
  # chart_version = "65.5.0"    # optional pin
}

# Optional Grafana (can be applied now or later)
module "grafana" {
  source = "./modules/grafana"
  count  = var.create_grafana ? 1 : 0

  namespace    = var.grafana_namespace
  release_name = var.grafana_release
  service_type = var.grafana_service_type

  # match module var names
  persistence_size = var.grafana_storage_size
  # leave persistence_enabled default (true) inside the module, or add a var here if you want

  admin_user     = var.grafana_admin_user
  admin_password = var.grafana_admin_pass

  prometheus_url = local.prometheus_url_effective
  dashboards     = var.grafana_dashboards

  # Static list is fine even if count=0; no ternary needed
  depends_on = [kubernetes_storage_class.default_gp3]
}
