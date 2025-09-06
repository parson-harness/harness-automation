# Toggle on/off if you want cluster-admin for POV
variable "delegate_cluster_admin" {
  description = "Grant cluster-admin to the delegate ServiceAccount"
  type        = bool
  default     = true
}

resource "kubernetes_namespace_v1" "delegate" {
  metadata {
    name   = var.delegate_namespace
    labels = { owner = var.tag_owner }
  }
  depends_on = [module.eks] # ensure cluster exists first
}

resource "kubernetes_service_account_v1" "delegate" {
  metadata {
    name      = var.delegate_service_account
    namespace = kubernetes_namespace_v1.delegate.metadata[0].name
    labels    = { owner = var.tag_owner }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_delegate.iam_role_arn
    }
  }
  automount_service_account_token = true

  depends_on = [module.eks] # wait for API to be ready
}

# (Optional) POV-friendly RBAC
resource "kubernetes_cluster_role_binding_v1" "delegate_admin" {
  count = var.delegate_cluster_admin ? 1 : 0

  metadata { name = "harness-delegate-admin" }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.delegate.metadata[0].name
    namespace = kubernetes_namespace_v1.delegate.metadata[0].name
  }

  depends_on = [kubernetes_service_account_v1.delegate]
}