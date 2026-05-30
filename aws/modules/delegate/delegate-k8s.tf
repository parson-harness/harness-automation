data "external" "delegate_version" {
  count = var.delegate_image_tag == "" ? 1 : 0

  program = [
    "python3",
    "-c",
    <<-PY
import json
import re
import sys
import urllib.request

query = json.load(sys.stdin)
registry = query["registry"]
repository = query["repository"]
url = f"https://{registry}/v2/{repository}/tags/list"
with urllib.request.urlopen(url, timeout=30) as response:
    payload = json.load(response)

pattern = re.compile(r"^\d{2}\.\d{2}\.\d{5}$")
tags = [tag for tag in payload.get("tags", []) if pattern.match(tag)]
if not tags:
    raise SystemExit("No plain delegate release tags found in public GAR")

def version_key(tag):
    return tuple(int(part) for part in tag.split("."))

latest = max(tags, key=version_key)
json.dump({"tag": latest}, sys.stdout)
    PY
  ]

  query = {
    registry   = var.delegate_image_registry
    repository = var.delegate_image_repository
  }
}

locals {
  delegate_release_name_effective = var.delegate_release_name != "" ? var.delegate_release_name : var.delegate_name
  delegate_image_tag_effective    = var.delegate_image_tag != "" ? var.delegate_image_tag : data.external.delegate_version[0].result.tag
  delegate_image_effective        = "${var.delegate_image_registry}/${var.delegate_image_repository}:${local.delegate_image_tag_effective}"
  delegate_tags_effective         = length(var.delegate_tags) > 0 ? join(",", var.delegate_tags) : ""
  delegate_upgrader_token_effective = var.delegate_upgrader_token != "" ? var.delegate_upgrader_token : var.delegate_token
}

resource "kubernetes_namespace_v1" "delegate" {
  metadata {
    name = var.delegate_namespace
    labels = {
      Owner = var.tag_owner
    }
  }
}

resource "kubernetes_service_account_v1" "delegate" {
  metadata {
    name      = var.delegate_service_account
    namespace = kubernetes_namespace_v1.delegate.metadata[0].name
    labels = {
      Owner = var.tag_owner
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }

  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "delegate_token" {
  metadata {
    name      = "${local.delegate_release_name_effective}-delegate-token"
    namespace = kubernetes_namespace_v1.delegate.metadata[0].name
    labels = {
      Owner = var.tag_owner
    }
  }

  data = {
    DELEGATE_TOKEN = base64encode(var.delegate_token)
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "delegate_upgrader_token" {
  count = var.delegate_upgrader_enabled ? 1 : 0

  metadata {
    name      = "${local.delegate_release_name_effective}-upgrader-token"
    namespace = kubernetes_namespace_v1.delegate.metadata[0].name
    labels = {
      Owner = var.tag_owner
    }
  }

  data = {
    UPGRADER_TOKEN = base64encode(local.delegate_upgrader_token_effective)
  }

  type = "Opaque"
}

resource "helm_release" "delegate" {
  name       = local.delegate_release_name_effective
  namespace  = kubernetes_namespace_v1.delegate.metadata[0].name
  repository = "https://app.harness.io/storage/harness-download/delegate-helm-chart/"
  chart      = "harness-delegate-ng"
  version    = var.delegate_chart_version != "" ? var.delegate_chart_version : null

  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    accountId             = var.delegate_account_id
    annotations           = var.delegate_annotations
    custom_envs           = var.delegate_custom_envs
    delegateAnnotations   = var.delegate_annotations
    delegateDockerImage   = local.delegate_image_effective
    delegateName          = var.delegate_name
    description           = var.delegate_description
    existingDelegateToken = kubernetes_secret_v1.delegate_token.metadata[0].name
    k8sPermissionsType    = var.delegate_k8s_permissions_type
    k8sServiceAccount     = kubernetes_service_account_v1.delegate.metadata[0].name
    managerEndpoint       = var.delegate_manager_endpoint
    nextGen               = true
    pollForTasks          = tostring(var.delegate_poll_for_tasks)
    replicas              = var.delegate_replicas
    tags                  = local.delegate_tags_effective
    upgrader = {
      enabled               = var.delegate_upgrader_enabled
      existingUpgraderToken = var.delegate_upgrader_enabled ? kubernetes_secret_v1.delegate_upgrader_token[0].metadata[0].name : ""
    }
  })]

  depends_on = [
    kubernetes_service_account_v1.delegate,
    kubernetes_secret_v1.delegate_token,
  ]
}

output "namespace" {
  value = kubernetes_namespace_v1.delegate.metadata[0].name
}

output "service_account_name" {
  value = kubernetes_service_account_v1.delegate.metadata[0].name
}

output "release_name" {
  value = helm_release.delegate.name
}

output "delegate_image" {
  value = local.delegate_image_effective
}

output "delegate_image_tag" {
  value = local.delegate_image_tag_effective
}