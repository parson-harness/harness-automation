# aws/iam-irsa/main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

# Only read the cluster if explicitly told to (standalone mode)
data "aws_eks_cluster" "this" {
  count = var.resolve_from_cluster ? 1 : 0
  name  = var.cluster_name
}

locals {
  # Safe: null if both are unknown; precondition on the role enforces non-null at apply.
  effective_oidc_issuer_url = try(
    coalesce(
      var.oidc_issuer_url,
      try(data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer, null)
    ),
    null
  )

  effective_oidc_provider_arn = coalesce(
    var.oidc_provider_arn,
    try(data.aws_iam_openid_connect_provider.by_url[0].arn, null)
  )

  sa_sub                 = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
  effective_cluster_name = coalesce(var.cluster_name, "unknown-cluster")
}


# Only look up the OIDC provider by URL when we are resolving from an existing cluster.
# Count depends ONLY on a simple variable (known at plan time).
data "aws_iam_openid_connect_provider" "by_url" {
  count = var.resolve_from_cluster ? 1 : 0
  url = coalesce(
    var.oidc_issuer_url,
    try(data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer, null)
  )
}


data "aws_partition" "current" {}

# Trust policy for IRSA
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.effective_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.effective_oidc_issuer_url, "https://", "")}:sub"
      values   = [local.sa_sub]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.effective_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "delegate" {
  name               = coalesce(var.role_name, "${local.effective_cluster_name}-${var.namespace}-${var.service_account_name}-irsa")
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "IRSA role for Harness delegate on ${local.effective_cluster_name} (${var.namespace}/${var.service_account_name})"
  tags = {
    managed-by = "terraform"
    component  = "harness-delegate"
    cluster    = local.effective_cluster_name
  }

  lifecycle {
    precondition {
      condition     = local.effective_oidc_provider_arn != null && local.effective_oidc_issuer_url != null
      error_message = "OIDC not resolved. If creating EKS in the same apply, set resolve_from_cluster=false and pass both oidc_provider_arn and oidc_issuer_url."
    }
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
