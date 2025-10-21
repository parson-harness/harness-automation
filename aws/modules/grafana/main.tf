resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

# Build Helm values dynamically
locals {
  values = {
    service = { type = var.service_type }

    persistence = merge(
      {
        enabled = var.persistence_enabled
        size    = var.persistence_size
      },
      length(var.persistence_sc_name) > 0 ? { storageClassName = var.persistence_sc_name } : {}
    )

    adminUser     = var.admin_user
    adminPassword = var.admin_password != "" ? var.admin_password : null

    datasources = var.prometheus_url != "" ? {
      "datasources.yaml" = {
        apiVersion  = 1
        datasources = [{
          name      = "Prometheus"
          type      = "prometheus"
          access    = "proxy"
          url       = var.prometheus_url
          isDefault = true
          editable  = true
        }]
      }
    } : {}

    dashboardsProvider = {
      enabled = length(var.dashboards) > 0
    }

    dashboards = length(var.dashboards) > 0 ? {
      "default" = {
        for d in var.dashboards :
        "gnet-${d.gnet_id}" => {
          gnetId     = d.gnet_id
          revision   = d.revision
          datasource = d.datasource
        }
      }
    } : {}
  }
}

resource "helm_release" "grafana" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "10.1.2"
  timeout    = var.timeout_seconds
  values     = [yamlencode(local.values)]

  depends_on = [kubernetes_namespace.ns]
}
