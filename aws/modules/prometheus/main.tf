# aws/modules/prometheus/main.tf
resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  # Important: make Helm not wait when everything is "paused"
  wait            = (var.prometheus_replicas + var.alertmanager_replicas) > 0
  timeout         = 600
  atomic          = true
  replace         = true
  cleanup_on_fail = true

  values = [yamlencode({
    grafana = { enabled = false }

    prometheus = {
      prometheusSpec = {
        replicas = var.prometheus_replicas
        # keep your existing storage config; replicas=0 keeps PVCs but stops pods
      }
    }

    alertmanager = {
      enabled = true
      alertmanagerSpec = {
        replicas = var.alertmanager_replicas
      }
    }

    kube-state-metrics = {
      enabled = var.kube_state_metrics_enabled
    }

    nodeExporter = {
      enabled = var.node_exporter_enabled
    }
  })]
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
