# modules/sonarqube/main.tf
locals {
  base_values = templatefile("${path.module}/values.yaml.tmpl", {
    service_type       = var.service_type
    storage_class_name = var.storage_class_name
    persistence_size   = var.persistence_size
    resources          = var.resources
    annotations        = var.annotations
    node_selector      = var.node_selector
    tolerations        = var.tolerations
  })

  has_extra   = length(trimspace(var.extra_values)) > 0
  values_list = local.has_extra ? [local.base_values, var.extra_values] : [local.base_values]
}

resource "kubernetes_namespace" "this" {
  count = var.enabled && var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "sonarqube" {
  count            = var.enabled ? 1 : 0
  name             = var.release_name
  repository       = var.chart_repo
  chart            = var.chart_name
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = false

  # pass multiple YAML docs as a proper list
  values = local.values_list

  timeout         = 1200
  wait            = true
  cleanup_on_fail = true

  depends_on = [kubernetes_namespace.this]
}
