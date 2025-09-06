#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-$(terraform output -raw cluster_name 2>/dev/null || echo parson-eks)}"
REGION="${REGION:-$(terraform output -raw region 2>/dev/null || echo us-east-1)}"
NS="${NS:-$(terraform output -raw delegate_namespace 2>/dev/null || echo harness-delegate-ng)}"

# Point kubectl at the right cluster if it still exists (don’t fail if it doesn’t)
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME" >/dev/null 2>&1 || true

# Uninstall the Helm release if it’s there (wait so hooks/CRDs clean up)
if helm -n "$NS" status helm-delegate >/dev/null 2>&1; then
  helm -n "$NS" uninstall helm-delegate --wait --timeout 5m || true
fi

# Delete the clusterrolebinding we created outside Terraform
kubectl delete clusterrolebinding harness-delegate-admin --ignore-not-found=true || true

# IMPORTANT: Don’t delete the namespace/ServiceAccount here if Terraform manages them.
# Terraform destroy will handle TF-managed k8s resources.

# Destroy all infra
terraform destroy -auto-approve
