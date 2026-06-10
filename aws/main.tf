# aws/main.tf

# Optionally create EKS
module "eks" {
  source = "./modules/eks"
  count  = var.create_eks ? 1 : 0

  cluster                  = var.cluster
  tag_owner                = var.tag_owner
  cluster_version          = var.cluster_version
  instance_type            = var.instance_type
  min_size                 = var.min_size
  max_size                 = var.max_size
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  mixed_capacity_enabled   = var.mixed_capacity_enabled
  spot_percentage          = var.spot_percentage
  spot_instance_types      = var.spot_instance_types
  warm_az                  = var.warm_az
  warm_desired             = var.warm_desired
  delegate_namespace       = var.delegate_namespace
  delegate_service_account = var.delegate_service_account
  artifacts_bucket         = var.artifacts_bucket
  ecr_repo_prefix          = var.ecr_repo_prefix
  assume_role_arns         = var.assume_role_arns
}

# Resolve target cluster name for both paths
locals {
  target_cluster_name = var.create_eks ? module.eks[0].cluster_name : var.existing_cluster_name
  cluster_autoscaler_image_tag_effective = var.cluster_autoscaler_image_tag != "" ? var.cluster_autoscaler_image_tag : "v${var.cluster_version}.0"
  cluster_autoscaler_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.target_cluster_name}" = "owned"
          }
        }
      }
    ]
  })
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

  resolve_from_cluster          = var.create_eks ? false : true
  oidc_provider_arn             = var.create_eks ? module.eks[0].oidc_provider_arn : null
  oidc_issuer_url               = var.create_eks ? module.eks[0].cluster_oidc_issuer_url : null
  allow_all_delegate_namespaces = var.allow_all_delegate_namespaces
}

module "cluster_autoscaler_irsa" {
  source = "./modules/iam-irsa"
  count  = var.enable_cluster_autoscaler ? 1 : 0

  cluster_name         = local.target_cluster_name
  namespace            = var.cluster_autoscaler_namespace
  service_account_name = var.cluster_autoscaler_service_account_name
  role_name            = "${local.target_cluster_name}-cluster-autoscaler-irsa"

  resolve_from_cluster = var.create_eks ? false : true
  oidc_provider_arn    = var.create_eks ? module.eks[0].oidc_provider_arn : null
  oidc_issuer_url      = var.create_eks ? module.eks[0].cluster_oidc_issuer_url : null

  inline_policy_json = local.cluster_autoscaler_policy_json
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
  namespace = var.grafana_namespace

  prometheus_replicas        = var.prometheus_replicas
  alertmanager_replicas      = var.alertmanager_replicas
  kube_state_metrics_enabled = var.kube_state_metrics_enabled
  node_exporter_enabled      = var.node_exporter_enabled
}

module "cluster_autoscaler" {
  source = "./modules/cluster-autoscaler"
  count  = var.enable_cluster_autoscaler ? 1 : 0

  cluster_name         = local.target_cluster_name
  namespace            = var.cluster_autoscaler_namespace
  service_account_name = var.cluster_autoscaler_service_account_name
  aws_region           = var.region
  chart_version        = var.cluster_autoscaler_chart_version
  image_tag            = local.cluster_autoscaler_image_tag_effective
  replica_count        = var.cluster_autoscaler_replica_count
  role_arn             = module.cluster_autoscaler_irsa[0].role_arn

  depends_on = [module.cluster_autoscaler_irsa]
}

module "delegate" {
  source = "./modules/delegate"
  count  = var.create_delegate ? 1 : 0

  delegate_namespace            = var.delegate_namespace
  delegate_service_account      = var.delegate_service_account
  delegate_name                 = var.delegate_name
  delegate_release_name         = var.delegate_release_name
  delegate_account_id           = var.delegate_account_id
  delegate_token                = var.delegate_token
  delegate_manager_endpoint     = var.delegate_manager_endpoint
  delegate_replicas             = var.delegate_replicas
  delegate_k8s_permissions_type = var.delegate_k8s_permissions_type
  delegate_poll_for_tasks       = var.delegate_poll_for_tasks
  delegate_description          = var.delegate_description
  delegate_tags                 = var.delegate_tags
  delegate_annotations          = var.delegate_annotations
  delegate_custom_envs          = var.delegate_custom_envs
  delegate_chart_version        = var.delegate_chart_version
  delegate_image_registry       = var.delegate_image_registry
  delegate_image_repository     = var.delegate_image_repository
  delegate_image_tag            = var.delegate_image_tag
  delegate_upgrader_enabled     = var.delegate_upgrader_enabled
  delegate_upgrader_token       = var.delegate_upgrader_token
  irsa_role_arn                 = module.iam_irsa.role_arn
  tag_owner                     = var.tag_owner

  depends_on = [module.iam_irsa]
}

# Optional Grafana (can be applied now or later)
# Only attempt DNS if we don't already have an IP
# Resolve NLB A record only if we have a hostname and no IP yet
data "dns_a_record_set" "ingress_nlb" {
  count = (
    try(module.ingress_nginx.lb_ip, "") == "" &&
    try(module.ingress_nginx.lb_hostname, "") != ""
  ) ? 1 : 0
  host = module.ingress_nginx.lb_hostname
}

locals {
  # First: use the direct IP if the module exposed one
  # Else: if the DNS lookup ran AND returned an address, use that
  # Else: null (still provisioning)
  ingress_ip = (
    try(module.ingress_nginx.lb_ip, "") != "" ? module.ingress_nginx.lb_ip :
    (length(data.dns_a_record_set.ingress_nlb) > 0 &&
      length(data.dns_a_record_set.ingress_nlb[0].addrs) > 0
      ? data.dns_a_record_set.ingress_nlb[0].addrs[0]
    : null)
  )

  grafana_host_effective = (
    var.grafana_host != "" ? var.grafana_host :
    (local.ingress_ip != null ? "${local.ingress_ip}.sslip.io" : null)
  )
}

module "grafana" {
  source = "./modules/grafana"
  count  = var.create_grafana ? 1 : 0

  namespace    = var.grafana_namespace
  release_name = var.grafana_release
  service_type = var.grafana_service_type
  replica_count = var.replica_count

  host                = local.grafana_host_effective != null ? local.grafana_host_effective : ""
  use_alb             = false
  cluster_issuer_name = "letsencrypt-prod"

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

module "ingress_nginx" {
  source = "./modules/ingress-nginx"
  # chart_version = "4.11.1"
  # lb_type       = "nlb"
  # lb_scheme     = "internet-facing"
}

module "cert_manager" {
  source        = "./modules/cert-manager"
  acme_email    = var.acme_email # add this var to your root variables.tf/tfvars
  ingress_class = "nginx"
}

# Optional SonarQube (can be applied now or later)
module "sonarqube" {
  source = "./modules/sonarqube"

  # --- Flip this to true to install, false to skip/destroy
  enabled = var.create_sonarqube
  replica_count = var.sonarqube_replica_count

  namespace        = var.grafana_namespace
  create_namespace = false
  release_name     = "sonarqube"
  chart_name       = "sonarqube"
  chart_repo       = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart_version    = null # <-- pin a version you’ve validated

  service_type       = "LoadBalancer"
  storage_class_name = "gp3"
  persistence_size   = "20Gi"

  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
  }

  extra_values = <<-YAML
  sonarProperties:
    sonar.forceAuthentication: "true"

  monitoringPasscode: "${var.sonarqube_monitoring_passcode}"

  community:
    enabled: true
  
  ingress:
    enabled: false
  YAML
}