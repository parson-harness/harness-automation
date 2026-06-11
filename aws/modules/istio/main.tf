terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.1, < 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
  }
}

locals {
  namespaces = toset(distinct(compact([
    var.namespace,
    var.gateway_namespace,
    var.enable_kiali ? var.kiali_namespace : null,
  ])))
}

resource "kubernetes_namespace_v1" "this" {
  for_each = var.enabled ? local.namespaces : toset([])

  metadata {
    name = each.value
  }
}

resource "helm_release" "base" {
  count = var.enabled ? 1 : 0

  name             = "istio-base"
  namespace        = var.namespace
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  timeout          = 1200

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "istiod" {
  count = var.enabled ? 1 : 0

  name             = "istiod"
  namespace        = var.namespace
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = var.istiod_replica_count > 0
  timeout          = 1200

  values = [yamlencode({
    pilot = {
      autoscaleEnabled = false
      replicaCount     = var.istiod_replica_count
    }
    meshConfig = {
      accessLogFile = "/dev/stdout"
    }
  })]

  depends_on = [helm_release.base]
}

resource "helm_release" "ingress_gateway" {
  count = var.enabled ? 1 : 0

  name             = "istio-ingressgateway"
  namespace        = var.gateway_namespace
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = var.ingress_gateway_replica_count > 0
  timeout          = 1200

  values = [yamlencode({
    service = {
      type        = var.ingress_gateway_service_type
      annotations = var.ingress_gateway_service_annotations
    }
    autoscaling = {
      enabled = false
    }
    replicaCount = var.ingress_gateway_replica_count
  })]

  depends_on = [helm_release.istiod]
}

resource "helm_release" "kiali" {
  count = var.enabled && var.enable_kiali ? 1 : 0

  name             = "kiali"
  namespace        = var.kiali_namespace
  repository       = "https://kiali.org/helm-charts"
  chart            = "kiali-server"
  version          = var.kiali_chart_version
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1200

  values = [yamlencode({
    auth = {
      strategy = "anonymous"
    }
    deployment = {
      cluster_wide_access = true
      service_type        = var.kiali_service_type
    }
    external_services = {
      istio = {
        root_namespace = var.namespace
      }
      prometheus = {
        enabled = true
        url     = var.prometheus_url
      }
    }
  })]

  depends_on = [helm_release.istiod]
}

data "kubernetes_service_v1" "ingress_gateway" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = helm_release.ingress_gateway[0].name
    namespace = var.gateway_namespace
  }

  depends_on = [helm_release.ingress_gateway]
}
