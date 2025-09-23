# aws/iam-irsa/main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Resolve/derive the OIDC provider
locals {
  oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_openid_connect_provider" "this" {
  # If caller provided an ARN, use that; else look up by URL
  arn = var.oidc_provider_arn != null ? var.oidc_provider_arn : null

  # Lookup by URL when ARN not provided
  url = var.oidc_provider_arn == null ? local.oidc_issuer_url : null
}

# k8s SA subject that will assume the role
locals {
  sa_sub = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

data "aws_partition" "current" {}

# Trust policy for IRSA
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer_url, "https://", "")}:sub"
      values   = [local.sa_sub]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "delegate" {
  name               = coalesce(var.role_name, "${var.cluster_name}-${var.namespace}-${var.service_account_name}-irsa")
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "IRSA role for Harness delegate on ${var.cluster_name} (${var.namespace}/${var.service_account_name})"
  tags = {
    managed-by = "terraform"
    component  = "harness-delegate"
    cluster    = var.cluster_name
  }
}

resource "aws_iam_policy" "delegate_inline" {
  name        = "${aws_iam_role.delegate.name}-policy"
  description = "Delegate inline policy"
  policy      = var.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.delegate.name
  policy_arn = aws_iam_policy.delegate_inline.arn
}
