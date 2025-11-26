# aws/modules/grafana/main.tf
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

# Build Helm values dynamically
locals {
  host      = try(coalesce(var.host, ""), "")
  have_host = length(local.host) > 0

  ingress_block = {
    # object shape is identical regardless of have_host
    enabled          = local.have_host
    ingressClassName = "nginx"

    # always a map(string); add extra keys only when we have a host
    annotations = merge(
      {
        "kubernetes.io/ingress.class"                    = "nginx"
        "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      },
      local.have_host ? {
        "kubernetes.io/tls-acme"                         = "true"
        "cert-manager.io/cluster-issuer"                 = var.cluster_issuer_name
        "nginx.ingress.kubernetes.io/proxy-hide-headers" = "X-Frame-Options"
      } : {}
    )

    # keep keys present in both branches; empty when disabled
    hosts    = local.have_host ? [local.host] : []
    path     = "/"
    pathType = "Prefix"
    tls = local.have_host ? [{
      hosts      = [local.host]
      secretName = "grafana-tls"
    }] : []
  }

  grafana_ini_block = {
    "grafana.ini" = merge(
      {
        security = {
          allow_embedding = true
          cookie_samesite = "none"
          cookie_secure   = true
        }
      },
      local.have_host ? {
        server = { root_url = "https://${local.host}" }
      } : {}
    )
  }

  values = merge(
    {
      service            = { type = "ClusterIP" }
      deploymentStrategy = { type = "Recreate" }

      persistence = merge(
        { enabled = var.persistence_enabled, size = var.persistence_size },
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
            options         = { path = "/var/lib/grafana/dashboards/default" }
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
    },
    { ingress = local.ingress_block },
    local.grafana_ini_block
  )
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

