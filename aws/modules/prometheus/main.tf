# aws/modules/prometheus/main.tf
resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  # Disable Grafana here – you provision Grafana separately as a TF module
  set = [
    {
      name  = "grafana.enabled"
      value = "false"
    }
  ]

  wait            = true
  timeout         = 600
  replace         = true
  cleanup_on_fail = true
}

resource "kubernetes_service_v1" "prometheus_incluster" {
  metadata {
    name      = "prometheus-internal"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "prometheus-internal"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus"             = "monitoring-kube-prometheus-prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
