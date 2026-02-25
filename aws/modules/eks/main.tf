# aws/eks/main.tf
####################################
# Data & locals
####################################
data "aws_availability_zones" "available" {
  # Filter out local zones for managed node groups
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Discover account, region, partition from the inherited root provider
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

####################################
# Per-AZ locals for node groups
####################################
locals {
  eks_azs         = module.vpc.azs
  eks_public_subs = module.vpc.public_subnets

  # If you want one warm node, set these in tfvars (example: "us-east-1a", 1)
  warm_az      = try(var.warm_az, null)
  warm_desired = try(var.warm_desired, 0)
}
locals {
  cluster_name = "${var.cluster}-${var.tag_owner}"

  # Keep naming simple and collision-proof via name_prefix (no regex needed)
  policy_pref = "eks-${local.cluster_name}-describe-regions-"

  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id

  # example: if you build an ECR repo ARN with an optional prefix
  ecr_repo_suffix = var.ecr_repo_prefix != "" ? "${var.ecr_repo_prefix}*" : "*"
  ecr_repo_arn    = "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${local.ecr_repo_suffix}"
}

####################################
# Minimal managed policy for node roles
####################################
resource "aws_iam_policy" "custom_node_policy_describe_regions" {
  name_prefix = local.policy_pref

  description = "Allow EKS worker nodes EC2 and ASG permissions for Harness deployments (scoped to ${local.cluster_name})"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions",
          "ec2:DescribeImages",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2LaunchTemplates"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:RunInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:AttachLoadBalancers",
          "autoscaling:AttachLoadBalancerTargetGroups",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:CreateOrUpdateTags",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DeleteLifecycleHook",
          "autoscaling:DeletePolicy",
          "autoscaling:DeleteScheduledAction",
          "autoscaling:DeleteTags",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:DescribeLoadBalancers",
          "autoscaling:DescribeLoadBalancerTargetGroups",
          "autoscaling:DescribePolicies",
          "autoscaling:DescribeScheduledActions",
          "autoscaling:DescribeTags",
          "autoscaling:DetachLoadBalancers",
          "autoscaling:DetachLoadBalancerTargetGroups",
          "autoscaling:PutLifecycleHook",
          "autoscaling:PutScalingPolicy",
          "autoscaling:PutScheduledUpdateGroupAction",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:StartInstanceRefresh",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Owner     = var.tag_owner
    ManagedBy = "Terraform"
    Cluster   = local.cluster_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################################
# VPC  (public nodes; no NAT/EIP needed)
####################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.cluster}-vpc"
  tags = { Owner = var.tag_owner }

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # Internet Gateway yes; NAT disabled to avoid EIP quota
  create_igw           = true
  enable_nat_gateway   = false
  enable_dns_hostnames = true

  # Ensure instances launched in public subnets get public IPs
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

####################################
# EKS cluster (public subnets)
####################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.32"

  enable_irsa = true
  tags        = { Owner = var.tag_owner }

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  # One node group per AZ, pinned to a single subnet in that AZ
  eks_managed_node_groups = {
    for idx, az in local.eks_azs :
    "ng-${az}" => {
      name            = "ng-${az}"
      use_name_prefix = true
      subnet_ids      = [element(local.eks_public_subs, idx)]
      instance_types  = [var.instance_type]
      min_size        = var.min_size
      max_size        = var.max_size
      # Keep one warm node only in the selected warm_az
      desired_size = (local.warm_az == az ? local.warm_desired : 0)
      timeouts     = { delete = "60m" }
      iam_role_additional_policies = {
        custom = aws_iam_policy.custom_node_policy_describe_regions.arn
      }
      tags = { Owner = var.tag_owner }
    }
  }

  cluster_timeouts = { delete = "60m" }

  # EBS CSI (with IRSA)
  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }
}


####################################
# EBS CSI IRSA
####################################
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role  = true
  role_name    = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url = module.eks.cluster_oidc_issuer_url

  role_policy_arns = [data.aws_iam_policy.ebs_csi_policy.arn]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:ebs-csi-controller-sa"
  ]
}

####################################
# Harness Delegate IRSA (managed policies + ARNs)
####################################

# ECR push/pull + describes (scoped to repo prefix or all repos)
resource "aws_iam_policy" "delegate_ecr" {
  name_prefix = "harness-delegate-ecr-${local.cluster_name}-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcrAuthAndDescribes"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = local.ecr_repo_arn
      },
      {
        Sid      = "EcrCreateRepository"
        Effect   = "Allow"
        Action   = ["ecr:CreateRepository"]
        Resource = "*"
      }
    ]
  })
  tags = { Owner = var.tag_owner, Cluster = local.cluster_name }
}

# ECS deploy ops + constrained PassRole
resource "aws_iam_policy" "delegate_ecs" {
  name_prefix = "harness-delegate-ecs-${local.cluster_name}-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecs:Describe*", "ecs:List*"], Resource = "*" },
      { Effect = "Allow", Action = ["ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition"], Resource = "*" },
      { Effect = "Allow", Action = ["ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService", "ecs:RunTask", "ecs:StopTask"], Resource = "*" },
      {
        Effect   = "Allow",
        Action   = ["iam:PassRole"],
        Resource = "arn:${local.partition}:iam::${local.account_id}:role/harness-ecs-*",
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      }
    ]
  })
  tags = { Owner = var.tag_owner, Cluster = local.cluster_name }
}

# Describes + CloudWatch Logs
resource "aws_iam_policy" "delegate_utility" {
  name_prefix = "harness-delegate-util-${local.cluster_name}-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ec2:Describe*", "eks:Describe*", "eks:List*", "elasticloadbalancing:Describe*", "autoscaling:Describe*", "cloudformation:Describe*", "cloudformation:List*"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" }
    ]
  })
  tags = { Owner = var.tag_owner, Cluster = local.cluster_name }
}

# Optional S3 R/W (only if artifacts_bucket is set)
resource "aws_iam_policy" "delegate_s3" {
  count       = var.artifacts_bucket != "" ? 1 : 0
  name_prefix = "harness-delegate-s3-${local.cluster_name}-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "S3ListBucket", Effect = "Allow", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::${var.artifacts_bucket}" },
      { Sid = "S3RWObjects", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"], Resource = "arn:aws:s3:::${var.artifacts_bucket}/*" }
    ]
  })
  tags = { Owner = var.tag_owner, Cluster = local.cluster_name }
}

# Optional cross-account assume role (only if you pass ARNs)
resource "aws_iam_policy" "delegate_sts" {
  count       = length(var.assume_role_arns) > 0 ? 1 : 0
  name_prefix = "harness-delegate-sts-${local.cluster_name}-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CrossAccountAssumeRole"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = var.assume_role_arns
      }
    ]
  })
  tags = { Owner = var.tag_owner, Cluster = local.cluster_name }
}

# Build the final list of policy ARNs to attach
locals {
  delegate_role_policy_arns = concat(
    [
      aws_iam_policy.delegate_ecr.arn,
      aws_iam_policy.delegate_ecs.arn,
      aws_iam_policy.delegate_utility.arn,
    ],
    var.artifacts_bucket != "" ? [aws_iam_policy.delegate_s3[0].arn] : [],
    length(var.assume_role_arns) > 0 ? [aws_iam_policy.delegate_sts[0].arn] : []
  )
}

# IRSA role bound to the delegate ServiceAccount; attach managed policies above
module "irsa_delegate" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role  = true
  role_name    = "harness-delegate-${local.cluster_name}"
  provider_url = module.eks.cluster_oidc_issuer_url

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${var.delegate_namespace}:${var.delegate_service_account}"
  ]

  role_policy_arns = local.delegate_role_policy_arns

  tags = {
    Owner   = var.tag_owner
    Cluster = local.cluster_name
  }
}
