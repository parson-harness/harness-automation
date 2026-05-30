resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.chart_version

  wait            = var.replica_count > 0
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    awsRegion = var.aws_region

    cloudProvider = "aws"

    fullnameOverride = "cluster-autoscaler"

    image = {
      repository = "registry.k8s.io/autoscaling/cluster-autoscaler"
      tag        = var.image_tag
    }

    priorityClassName = "system-cluster-critical"

    podAnnotations = {
      "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
    }

    replicaCount = var.replica_count

    extraArgs = {
      "balance-similar-node-groups"   = "true"
      "skip-nodes-with-local-storage" = "false"
      "skip-nodes-with-system-pods"   = "false"
    }

    rbac = {
      create = true
      serviceAccount = {
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.role_arn
        }
      }
    }
  })]
}

resource "kubernetes_cluster_role_v1" "cluster_autoscaler_storage" {
  metadata {
    name = "cluster-autoscaler-storage"
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "cluster_autoscaler_storage" {
  metadata {
    name = "cluster-autoscaler-storage"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cluster_autoscaler_storage.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account_name
    namespace = var.namespace
  }

  depends_on = [helm_release.cluster_autoscaler]
}
