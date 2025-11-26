terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.24.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.10.1, < 4.0.0" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.19.0" }
  }
}
resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

# Install cert-manager (with CRDs)
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = var.namespace
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  timeout          = 1200

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [kubernetes_namespace.ns]
}

# Staging issuer (faster troubleshooting, higher rate limits)
resource "kubectl_manifest" "issuer_staging" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: ${var.acme_email}
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: ${var.ingress_class}
YAML

  depends_on = [helm_release.cert_manager]
}

# Production issuer
resource "kubectl_manifest" "issuer_prod" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${var.acme_email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: ${var.ingress_class}
YAML

  depends_on = [helm_release.cert_manager]
}
