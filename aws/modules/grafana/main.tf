# aws/modules/grafana/main.tf
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

# Build Helm values dynamically
locals {
  values = {
    service = { type = var.service_type }
    deploymentStrategy = {
      type = "Recreate"
    }

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
        apiVersion = 1
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

    dashboardProviders = length(var.dashboards) > 0 ? {
      "dashboardproviders.yaml" = {
        apiVersion = 1
        providers = [{
          name            = "default"
          orgId           = 1
          folder          = ""
          type            = "file"
          disableDeletion = false
          editable        = true
          options = {
            path = "/var/lib/grafana/dashboards/default"
          }
        }]
      }
    } : {}

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
  count           = var.grafana_enabled ? 1 : 0
  name            = var.release_name
  namespace       = var.namespace
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "10.1.2"
  wait            = var.replica_count > 0
  timeout         = var.timeout_seconds
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode(
      merge(local.values, {
        replicas = var.replica_count
      })
    )
  ]

  depends_on = [kubernetes_namespace.ns]
}

