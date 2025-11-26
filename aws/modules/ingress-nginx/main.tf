# aws/ingress-nginx/main.tf
terraform {
  required_providers {
    helm       = { source = "hashicorp/helm" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

resource "helm_release" "ingress_nginx" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.chart_version
  create_namespace = true
  atomic           = true
  timeout          = 1200

  # All config via values (compatible across provider versions)
  values = [
    yamlencode({
      controller = {
        publishService = { enabled = true }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"   = var.lb_type
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = var.lb_scheme
            # Uncomment if you prefer IP target-type:
            # "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          }
        }
      }
    }),
    # optional pass-through from caller
    (length(var.extra_values) > 0 ? yamlencode(var.extra_values) : null)
  ]
}

# Read the created Service to surface LB details
data "kubernetes_service" "controller" {
  metadata {
    name      = "${var.release_name}-controller"
    namespace = var.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}

locals {
  lb_hostname = try(data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].hostname, null)
  lb_ip       = try(data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].ip, null)
  sslip_host  = local.lb_ip != null ? "${local.lb_ip}.sslip.io" : null
}
