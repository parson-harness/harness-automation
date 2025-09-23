# Root provider is already configured in aws/providers.tf with var.region

# Create EKS only when requested
module "eks" {
  source = "./eks"
  count  = var.create_eks ? 1 : 0

  # pass what your eks module needs
  cluster                  = var.cluster
  tag_owner                = var.tag_owner
  instance_type            = var.instance_type
  delegate_namespace       = var.delegate_namespace
  delegate_service_account = var.delegate_service_account
  artifacts_bucket         = var.artifacts_bucket
  ecr_repo_prefix          = var.ecr_repo_prefix
  assume_role_arns         = var.assume_role_arns
}

module "iam_irsa" {
  source               = "./iam-irsa"
  cluster_name         = var.create_eks ? module.eks[0].cluster_name : var.existing_cluster_name
  namespace            = var.delegate_namespace
  service_account_name = var.delegate_service_account

  resolve_from_cluster = var.create_eks ? false : true
  oidc_provider_arn    = var.create_eks ? module.eks[0].oidc_provider_arn : null
  oidc_issuer_url      = var.create_eks ? module.eks[0].cluster_oidc_issuer_url : null
}

