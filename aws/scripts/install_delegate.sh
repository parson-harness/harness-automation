#!/usr/bin/env bash
set -euo pipefail

# --- config (env overrides welcome) ---
CLUSTER_NAME="${CLUSTER_NAME:-$(terraform output -raw cluster_name 2>/dev/null || echo parson-eks)}"
REGION="${REGION:-$(terraform output -raw region 2>/dev/null || echo us-east-1)}"
NS="${NS:-$(terraform output -raw delegate_namespace 2>/dev/null || echo harness-delegate-ng)}"
SA="${SA:-$(terraform output -raw delegate_service_account 2>/dev/null || echo harness-delegate)}"
IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-$(terraform output -raw delegate_role_arn 2>/dev/null || true)}"

# Harness bits (do NOT commit the token)
DELEGATE_NAME="${DELEGATE_NAME:-${CLUSTER_NAME}-delegate}"
HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:?set HARNESS_ACCOUNT_ID env var}"
DELEGATE_TOKEN="${DELEGATE_TOKEN:?set DELEGATE_TOKEN env var}"
MANAGER_ENDPOINT="${MANAGER_ENDPOINT:-https://app.harness.io}"
DELEGATE_REPLICAS="${DELEGATE_REPLICAS:-1}"

# --- resolve delegate image tag from Docker Hub if not provided ---
# No auth required. We filter to tags like 25.08.86600 (stable).
if [[ -z "${DELEGATE_IMAGE:-}" ]]; then
  echo "Resolving latest delegate tag from Docker Hub…"
  HUB_URL="https://hub.docker.com/v2/repositories/harness/delegate/tags/?page_size=100&ordering=last_updated"

  if command -v jq >/dev/null 2>&1; then
    TAG="$(curl -fsSL "$HUB_URL" \
      | jq -r '.results[].name' \
      | grep -E '^[0-9]{2}\.[0-9]{2}\.[0-9]{5}$' \
      | sort -V \
      | tail -n1 || true)"
  else
    TAG="$(curl -fsSL "$HUB_URL" \
      | tr ',' '\n' \
      | grep -oE '"name":[[:space:]]*"[^"]+"' \
      | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/' \
      | grep -E '^[0-9]{2}\.[0-9]{2}\.[0-9]{5}$' \
      | sort -V \
      | tail -n1 || true)"
  fi

  if [[ -n "${TAG:-}" ]]; then
    # Pull from Docker Hub or GAR (default below).
    IMG_PREFIX="${DELEGATE_IMAGE_PREFIX:-us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate}"
    DELEGATE_IMAGE="${IMG_PREFIX}:${TAG}"
    echo "Using delegate image: ${DELEGATE_IMAGE}"
  else
    echo "WARN: Could not determine latest tag from Docker Hub."
    # Optional fallback: Harness API (needs HARNESS_API_KEY)
    if [[ -n "${HARNESS_API_KEY:-}" ]]; then
      API_BASE="${HARNESS_API_BASE:-https://app.harness.io}"
      VER_JSON="$(curl -sfSL -H "x-api-key: ${HARNESS_API_KEY}" \
        "${API_BASE}/ng/api/delegate-setup/latest-supported-version?accountIdentifier=${HARNESS_ACCOUNT_ID}" || true)"
      VERSION="$(printf '%s' "$VER_JSON" | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([0-9][0-9]\.[0-9][0-9]\.[0-9]\{5\}\)".*/\1/p')"
      if [[ -n "${VERSION:-}" ]]; then
        IMG_PREFIX="${DELEGATE_IMAGE_PREFIX:-us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate}"
        DELEGATE_IMAGE="${IMG_PREFIX}:${VERSION}"
        echo "Using delegate image from Harness API: ${DELEGATE_IMAGE}"
      else
        echo "WARN: Could not resolve a version; continuing without overriding delegateDockerImage."
      fi
    fi
  fi
fi

# Only pass image flag if set
IMAGE_FLAG=()
if [[ -n "${DELEGATE_IMAGE:-}" ]]; then
  IMAGE_FLAG+=(--set-string "delegateDockerImage=${DELEGATE_IMAGE}")
fi

echo "Cluster: $CLUSTER_NAME  Region: $REGION"
echo "Namespace: $NS  ServiceAccount: $SA"
echo "IRSA role: ${IRSA_ROLE_ARN:-<none>}"
echo "Delegate: $DELEGATE_NAME  Harness account: $HARNESS_ACCOUNT_ID"
echo

# 0) kubeconfig
aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME"

# 1) Ensure namespace exists (Terraform usually created it; this is safe)
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

# 2) Ensure SA exists and has the IRSA annotation
kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1 || kubectl -n "$NS" create serviceaccount "$SA"

ANNOTATION="eks.amazonaws.com/role-arn"
if [[ -n "${IRSA_ROLE_ARN:-}" ]]; then
  CURRENT_ARN="$(kubectl -n "$NS" get sa "$SA" -o jsonpath="{.metadata.annotations.${ANNOTATION}}" 2>/dev/null || true)"
  if [[ "$CURRENT_ARN" != "$IRSA_ROLE_ARN" ]]; then
    echo "Patching SA annotation ($ANNOTATION)"
    kubectl -n "$NS" annotate serviceaccount "$SA" "${ANNOTATION}=${IRSA_ROLE_ARN}" --overwrite
  fi
else
  echo "WARN: IRSA_ROLE_ARN empty; skipping SA annotation."
fi

# (Optional) cluster-admin for POV convenience
if [[ "${DELEGATE_CLUSTER_ADMIN:-true}" == "true" ]]; then
  kubectl create clusterrolebinding harness-delegate-admin \
    --clusterrole=cluster-admin \
    --serviceaccount="${NS}:${SA}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# 3) Helm install/upgrade
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/ >/dev/null 2>&1 || true
helm repo update
helm upgrade -i helm-delegate --namespace "$NS" --create-namespace=false \
  harness-delegate/harness-delegate-ng \
  --set-string delegateName="$DELEGATE_NAME" \
  --set-string accountId="$HARNESS_ACCOUNT_ID" \
  --set-string delegateToken="$DELEGATE_TOKEN" \
  --set-string managerEndpoint="$MANAGER_ENDPOINT" \
  --set replicas="$DELEGATE_REPLICAS" \
  --set upgrader.enabled=true \
  --set serviceAccount.create=false \
  --set-string serviceAccount.name="$SA" \
  --set rbac.create=true \
  --set rbac.clusterWideAccess=true \
  "${IMAGE_FLAG[@]}" \
  --wait --timeout 5m

# 4) Wait and verify
echo "Waiting for delegate deployment to become ready..."
kubectl -n "$NS" rollout status deploy/"$DELEGATE_NAME" --timeout=5m || true
kubectl -n "$NS" get pods -o wide

# 5) (Optional) IRSA smoke test
if [[ "${IRSA_SMOKETEST:-true}" == "true" ]]; then
  echo "IRSA test: aws sts get-caller-identity"
  cat <<EOF | kubectl -n "$NS" apply -f -
apiVersion: batch/v1
kind: Job
metadata: { name: irsa-test }
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: ${SA}
      containers:
      - name: aws
        image: amazon/aws-cli:2
        command: ["sh","-c","aws sts get-caller-identity && echo OK"]
EOF
  kubectl -n "$NS" wait --for=condition=complete job/irsa-test --timeout=120s || true
  kubectl -n "$NS" logs job/irsa-test || true
  kubectl -n "$NS" delete job irsa-test --now || true
fi

echo "Done. Delegate should appear in the Harness UI shortly."
