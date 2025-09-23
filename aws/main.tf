# aws/main.tf
module "eks" {
  source = "./eks"
  # pass only what the module actually needs
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
  cluster_name         = module.eks.cluster_name
  namespace            = var.delegate_namespace
  service_account_name = var.delegate_service_account
  # role_name / inline_policy_json if you use them
}